import 'dart:async';

import 'package:flutter/widgets.dart';

import '../dades/api_ribera.dart';
import '../models/models.dart';

enum EstatCarrega { inicial, carregant, llest, error }

/// Estat compartit del directori (ChangeNotifier de l'SDK, sense Riverpod).
///
/// Guarda els catàlegs, els filtres actius i els resultats de serveis,
/// centres i punts del mapa. Les pantalles l'escolten amb
/// [ListenableBuilder] o amb [EstatDirectori.of].
class DirectoriEstat extends ChangeNotifier {
  final ApiRibera api;

  DirectoriEstat(this.api);

  // ---- catàlegs
  List<Municipi> municipis = [];
  Catalegs catalegs = const Catalegs();
  EstatCarrega estatCatalegs = EstatCarrega.inicial;

  // ---- filtres i resultats
  Filtres filtres = const Filtres();
  List<ServeiResum> serveis = [];
  List<CentreResum> centres = [];
  List<CentreResum> punts = [];
  EstatCarrega estatResultats = EstatCarrega.inicial;
  String? error;

  Timer? _espera;
  int _peticio = 0;

  Future<void> inicialitza() async {
    estatCatalegs = EstatCarrega.carregant;
    notifyListeners();
    try {
      final res = await Future.wait([api.municipis(), api.catalegs()]);
      municipis = res[0] as List<Municipi>;
      catalegs = res[1] as Catalegs;
      estatCatalegs = EstatCarrega.llest;
    } catch (e) {
      estatCatalegs = EstatCarrega.error;
      error = e.toString();
    }
    notifyListeners();
    await carrega();
  }

  /// Torna a demanar serveis, centres i punts amb els filtres actuals.
  Future<void> carrega() async {
    final num = ++_peticio;
    estatResultats = EstatCarrega.carregant;
    error = null;
    notifyListeners();
    try {
      final f = filtres;
      final res = await Future.wait([api.serveis(f), api.centres(f), api.centres(f, nomesAmbPunt: true)]);
      if (num != _peticio) return; // ja hi ha una petició més nova
      serveis = res[0] as List<ServeiResum>;
      centres = res[1] as List<CentreResum>;
      punts = res[2] as List<CentreResum>;
      estatResultats = EstatCarrega.llest;
    } catch (e) {
      if (num != _peticio) return;
      estatResultats = EstatCarrega.error;
      error = e.toString();
    }
    notifyListeners();
  }

  /// Cerca de text amb una xicoteta espera per no fer una petició per tecla.
  void cerca(String text) {
    filtres = filtres.copyWith(text: text);
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 350), carrega);
  }

  void aplica(Filtres nous) {
    filtres = nous;
    carrega();
  }

  void netejaFiltres() {
    filtres = Filtres(text: filtres.text);
    carrega();
  }

  String? nomMunicipi(int? id) {
    if (id == null) return null;
    for (final m in municipis) {
      if (m.id == id) return m.nom;
    }
    return null;
  }

  String? nomCataleg(List<Ref> llista, String? codi) {
    if (codi == null) return null;
    for (final r in llista) {
      if (r.codi == codi) return r.nom;
    }
    return codi;
  }

  @override
  void dispose() {
    _espera?.cancel();
    super.dispose();
  }
}

/// Fa accessible el [DirectoriEstat] a tot l'arbre de widgets.
class EstatDirectori extends InheritedNotifier<DirectoriEstat> {
  const EstatDirectori({super.key, required DirectoriEstat estat, required super.child}) : super(notifier: estat);

  /// Obté l'estat i es reconstrueix quan canvia.
  static DirectoriEstat of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EstatDirectori>()!.notifier!;

  /// Obté l'estat sense subscriure's (per a callbacks).
  static DirectoriEstat llig(BuildContext context) =>
      context.getInheritedWidgetOfExactType<EstatDirectori>()!.notifier!;
}
