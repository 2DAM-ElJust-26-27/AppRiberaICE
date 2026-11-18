import 'package:flutter/foundation.dart';

import '../dades/api_ribera.dart';
import '../models/models.dart';

enum Autor { assistent, usuari }

/// Accions especials que pot triar l'usuari a més de respondre una pregunta.
enum Accio { resposta, reinicia, veureMapa, llevaMunicipi }

/// Opció de resposta ràpida (botó) d'un missatge de l'assistent.
class Opcio {
  final String text;
  final Accio accio;
  final String? valor; // codi de col·lectiu / tipus de centre o id de municipi
  final int? recompte;

  const Opcio(this.text, {this.accio = Accio.resposta, this.valor, this.recompte});
}

class Missatge {
  final Autor autor;
  final String text;
  final List<Opcio> opcions;
  final List<ServeiResum> serveis;

  const Missatge(this.autor, this.text, {this.opcions = const [], this.serveis = const []});
}

/// Pas de la conversa: què està preguntant l'assistent ara mateix.
enum Pas { collectiu, municipi, tipusCentre, resultats }

/// Assistent guiat «Carlos Collado» de la pestanya Serveis.
///
/// No és cap IA: fa preguntes fixes (per a qui, on, quin tipus de lloc) i
/// només ofereix opcions que tenen resultats amb les respostes anteriors.
/// Totes les consultes es fan contra l'API del directori.
///
/// És una classe normal de Dart (sense cap gestor d'estat): guarda la conversa i,
/// cada vegada que canvia, crida [onCanvi]. La pantalla hi passa una funció que
/// fa `setState` per tornar-se a dibuixar.
class AssistentEstat {
  static const nom = 'Carlos Collado';
  static const maxSenseMesPreguntes = 3;

  final ApiRibera api;
  final Duration pausa;

  /// S'executa cada vegada que canvia la conversa.
  VoidCallback? onCanvi;

  AssistentEstat(this.api, {this.pausa = const Duration(milliseconds: 450), this.onCanvi});

  void _avisa() => onCanvi?.call();

  final List<Missatge> missatges = [];
  Filtres filtres = const Filtres();
  Pas pas = Pas.collectiu;
  bool escrivint = false;
  List<ServeiResum> _actuals = [];

  /// Opcions actives: només les de l'últim missatge de l'assistent.
  List<Opcio> get opcionsActives =>
      missatges.isNotEmpty && missatges.last.autor == Autor.assistent ? missatges.last.opcions : const [];

  Future<void> comenca() async {
    missatges.clear();
    filtres = const Filtres();
    pas = Pas.collectiu;
    _avisa();
    await _diu('Hola! Sóc en $nom 👋\nT\'ajudaré a trobar el servei social o comunitari que necessites a la Ribera. '
        'Et faré unes poques preguntes. També pots escriure el que busques amb les teues paraules.');
    await _preguntaCollectiu();
  }

  /// L'usuari prem una opció.
  Future<void> tria(Opcio o) async {
    if (escrivint) return;
    _usuari(o.text);
    switch (o.accio) {
      case Accio.reinicia:
        await comenca();
        return;
      case Accio.veureMapa:
        // La pantalla ja ha aplicat els filtres a la pestanya Centres.
        await _diu('T\'he obert la pestanya Centres amb aquests filtres. Allí veuràs on es presten.', opcions: const [
          Opcio('Torna a començar', accio: Accio.reinicia),
        ]);
        return;
      case Accio.llevaMunicipi:
        filtres = filtres.copyWith(municipiId: () => null);
        await _mostraResultats(await _busca());
        return;
      case Accio.resposta:
        break;
    }
    switch (pas) {
      case Pas.collectiu:
        filtres = filtres.copyWith(collectiu: () => o.valor);
        await _despresDeCollectiu();
      case Pas.municipi:
        filtres = filtres.copyWith(municipiId: () => o.valor == null ? null : int.parse(o.valor!));
        await _despresDeMunicipi();
      case Pas.tipusCentre:
        filtres = filtres.copyWith(tipusCentre: () => o.valor);
        await _mostraResultats(await _busca());
      case Pas.resultats:
        break;
    }
  }

  /// L'usuari escriu text lliure: es fa una cerca per paraules amb els filtres triats fins ara.
  Future<void> escriu(String text) async {
    final t = text.trim();
    if (t.isEmpty || escrivint) return;
    _usuari(t);
    filtres = filtres.copyWith(text: t);
    final res = await _busca();
    if (res == null) return;
    if (res.isEmpty && (filtres.collectiu != null || filtres.municipiId != null || filtres.tipusCentre != null)) {
      // Provem només amb el text abans de dir que no hi ha res.
      final nomesText = Filtres(text: t);
      final r2 = await _cerca(nomesText);
      if (r2 != null && r2.isNotEmpty) {
        filtres = nomesText;
        await _diu('Amb les respostes d\'abans no he trobat res, però buscant només «$t» sí que n\'hi ha:');
        await _mostraResultats(r2, introduccio: false);
        return;
      }
    }
    await _mostraResultats(res);
  }

  // --------------------------------------------------------------- passos

  Future<void> _preguntaCollectiu() async {
    final tots = await _cerca(const Filtres());
    if (tots == null) return;
    pas = Pas.collectiu;
    await _diu('Per a qui busques ajuda?', opcions: [
      ..._opcions(tots, (s) => s.collectius, (r) => r.codi),
      Opcio('No ho sé / qualsevol persona', recompte: tots.length),
    ]);
  }

  Future<void> _despresDeCollectiu() async {
    final res = await _busca();
    if (res == null) return;
    final opcions = _opcions(res, (s) => s.municipis, (r) => r.id?.toString());
    if (res.length <= maxSenseMesPreguntes || opcions.isEmpty) return _mostraResultats(res);
    pas = Pas.municipi;
    await _diu('He trobat ${res.length} serveis. En quin municipi el necessites?', opcions: [
      ...opcions,
      Opcio('Qualsevol lloc', recompte: res.length),
    ]);
  }

  Future<void> _despresDeMunicipi() async {
    final res = await _busca();
    if (res == null) return;
    final opcions = _opcions(res, (s) => s.tipusCentre, (r) => r.codi);
    if (res.length <= maxSenseMesPreguntes || opcions.length < 2) return _mostraResultats(res);
    pas = Pas.tipusCentre;
    await _diu('Encara en tinc ${res.length}. Quin tipus de lloc prefereixes?', opcions: [
      ...opcions,
      Opcio('M\'és igual', recompte: res.length),
    ]);
  }

  /// Una opció per cada valor que apareix en els serveis (col·lectiu, municipi o tipus de centre),
  /// amb quants serveis el tenen, ordenades per nom. Així només s'ofereixen opcions amb resultats.
  List<Opcio> _opcions(List<ServeiResum> serveis, List<Ref> Function(ServeiResum) valors, String? Function(Ref) clau) {
    final recomptes = <String, int>{};
    final noms = <String, String>{};
    for (final s in serveis) {
      for (final r in valors(s)) {
        final k = clau(r);
        if (k == null) continue;
        recomptes[k] = (recomptes[k] ?? 0) + 1;
        noms[k] = r.nom;
      }
    }
    final claus = recomptes.keys.toList()..sort((a, b) => noms[a]!.compareTo(noms[b]!));
    return [for (final k in claus) Opcio(noms[k]!, valor: k, recompte: recomptes[k])];
  }

  Future<void> _mostraResultats(List<ServeiResum>? res, {bool introduccio = true}) async {
    if (res == null) return;
    pas = Pas.resultats;
    _actuals = res;
    if (res.isEmpty) {
      await _diu(
        'No he trobat cap servei amb aquestes condicions en les dades del directori. '
        'Això no vol dir que no n\'hi haja a la comarca: només descriu les dades que tenim.',
        opcions: [
          if (filtres.municipiId != null) const Opcio('Busca en qualsevol municipi', accio: Accio.llevaMunicipi),
          const Opcio('Torna a començar', accio: Accio.reinicia),
        ],
      );
      return;
    }
    final text = !introduccio
        ? ''
        : res.length == 1
            ? 'Aquest és el servei que encaixa amb el que m\'has dit:'
            : 'Aquests són els ${res.length} serveis que encaixen amb el que m\'has dit:';
    await _diu(text, serveis: res);
    await _diu('Toca un servei per vore la fitxa completa. Vols fer alguna cosa més?', opcions: [
      const Opcio('Vore on es presten al mapa', accio: Accio.veureMapa),
      if (filtres.municipiId != null) const Opcio('Busca en qualsevol municipi', accio: Accio.llevaMunicipi),
      const Opcio('Torna a començar', accio: Accio.reinicia),
    ]);
  }

  /// Serveis dels últims resultats (per passar-los al mapa).
  List<ServeiResum> get resultats => List.unmodifiable(_actuals);

  // --------------------------------------------------------------- utilitats

  Future<List<ServeiResum>?> _busca() => _cerca(filtres);

  Future<List<ServeiResum>?> _cerca(Filtres f) async {
    try {
      return await api.serveis(f);
    } catch (e) {
      await _diu('Ui, no puc consultar el directori ara mateix: $e', opcions: const [
        Opcio('Torna-ho a provar', accio: Accio.reinicia),
      ]);
      return null;
    }
  }

  void _usuari(String text) {
    missatges.add(Missatge(Autor.usuari, text));
    _avisa();
  }

  Future<void> _diu(String text, {List<Opcio> opcions = const [], List<ServeiResum> serveis = const []}) async {
    escrivint = true;
    _avisa();
    if (pausa > Duration.zero) await Future<void>.delayed(pausa);
    escrivint = false;
    missatges.add(Missatge(Autor.assistent, text, opcions: opcions, serveis: serveis));
    _avisa();
  }
}
