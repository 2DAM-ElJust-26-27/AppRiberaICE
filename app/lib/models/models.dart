/// Models del directori. Es construeixen a partir del JSON de l'API
/// (claus en snake_case). Els camps opcionals poden ser nuls: una dada
/// desconeguda no es substitueix mai per un valor inventat.
library;

part 'centre.dart';
part 'entitat.dart';
part 'servei.dart';

typedef Json = Map<String, dynamic>;

/// Estat d'una càrrega de dades des de l'API.
enum EstatCarrega { carregant, llest, error }

List<T> _llista<T>(dynamic v, T Function(Json) f) =>
    v is List ? v.whereType<Map>().map((e) => f(Map<String, dynamic>.from(e))).toList() : <T>[];

Ref? _ref(dynamic v) => v is Map ? Ref.fromJson(Map<String, dynamic>.from(v)) : null;

double? _doble(dynamic v) => v is num ? v.toDouble() : null;

/// Referència breu a un registre o valor de catàleg.
class Ref {
  final int? id;
  final String? codi;
  final String nom;

  const Ref({this.id, this.codi, required this.nom});

  factory Ref.fromJson(Json j) => Ref(
        id: (j['id'] as num?)?.toInt(),
        codi: j['codi'] as String?,
        nom: (j['nom'] as String?) ?? '',
      );
}

class Font {
  final String codi;
  final String? referencia;

  const Font({required this.codi, this.referencia});

  static Font? fromJson(dynamic j) =>
      j is Map ? Font(codi: j['codi'] as String, referencia: j['referencia'] as String?) : null;

  bool get esEnllac => referencia != null && referencia!.startsWith('http');
}

class Municipi {
  final int id;
  final String nom;
  final Ref? comarca;

  const Municipi({required this.id, required this.nom, this.comarca});

  factory Municipi.fromJson(Json j) =>
      Municipi(id: (j['id'] as num).toInt(), nom: j['nom'] as String, comarca: _ref(j['comarca']));
}

class Catalegs {
  final List<Ref> collectius;
  final List<Ref> tipusCentre;

  const Catalegs({this.collectius = const [], this.tipusCentre = const []});

  factory Catalegs.fromJson(Json j) => Catalegs(
        collectius: _llista(j['collectius'], Ref.fromJson),
        tipusCentre: _llista(j['tipus_centre'], Ref.fromJson),
      );
}

enum TipusContacte { telefon, correu, web, altre }

class Contacte {
  final String tipus;
  final String valor;

  const Contacte({required this.tipus, required this.valor});

  factory Contacte.fromJson(Json j) => Contacte(tipus: j['tipus'] as String, valor: j['valor'] as String);

  TipusContacte get classe {
    final t = tipus.toLowerCase();
    if (t.startsWith('tel')) return TipusContacte.telefon;
    if (t.contains('correu') || t.contains('mail')) return TipusContacte.correu;
    if (t == 'web' || valor.startsWith('http')) return TipusContacte.web;
    return TipusContacte.altre;
  }
}

class Franja {
  final int diaSetmana; // ISO: 1 = dilluns … 7 = diumenge
  final String horaInici;
  final String horaFi;
  final bool finalDiaSeguent;

  const Franja({required this.diaSetmana, required this.horaInici, required this.horaFi, this.finalDiaSeguent = false});

  factory Franja.fromJson(Json j) => Franja(
        diaSetmana: (j['dia_setmana'] as num).toInt(),
        horaInici: j['hora_inici'] as String,
        horaFi: j['hora_fi'] as String,
        finalDiaSeguent: (j['final_dia_seguent'] as bool?) ?? false,
      );

  static const dies = ['dilluns', 'dimarts', 'dimecres', 'dijous', 'divendres', 'dissabte', 'diumenge'];

  String get text =>
      '${dies[(diaSetmana - 1).clamp(0, 6)]} $horaInici–$horaFi${finalDiaSeguent ? ' (de l\'endemà)' : ''}';
}

class Horari {
  final String? tipus;
  final String? descripcio;
  final List<Franja> franges;

  const Horari({this.tipus, this.descripcio, this.franges = const []});

  factory Horari.fromJson(Json j) => Horari(
        tipus: j['tipus'] as String?,
        descripcio: j['descripcio'] as String?,
        franges: _llista(j['franges'], Franja.fromJson),
      );
}
