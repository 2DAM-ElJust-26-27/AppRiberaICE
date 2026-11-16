/// Models del directori. Es construeixen a partir del JSON de l'API
/// (claus en snake_case). Els camps opcionals poden ser nuls: una dada
/// desconeguda no es substitueix mai per un valor inventat.
library;

typedef Json = Map<String, dynamic>;

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

class ServeiResum {
  final int id;
  final String? codi;
  final String nom;
  final String? descripcio;
  final List<Ref> collectius;
  final List<Ref> entitats;
  final List<Ref> municipis;
  final List<Ref> tipusCentre;

  const ServeiResum({
    required this.id,
    this.codi,
    required this.nom,
    this.descripcio,
    this.collectius = const [],
    this.entitats = const [],
    this.municipis = const [],
    this.tipusCentre = const [],
  });

  factory ServeiResum.fromJson(Json j) => ServeiResum(
        id: (j['id'] as num).toInt(),
        codi: j['codi'] as String?,
        nom: j['nom'] as String,
        descripcio: j['descripcio'] as String?,
        collectius: _llista(j['collectius'], Ref.fromJson),
        entitats: _llista(j['entitats'], Ref.fromJson),
        municipis: _llista(j['municipis'], Ref.fromJson),
        tipusCentre: _llista(j['tipus_centre'], Ref.fromJson),
      );
}

class EntitatResum {
  final int id;
  final String? codi;
  final String nom;
  final Ref? formaJuridica;
  final String? sector;
  final Ref? municipi;

  const EntitatResum({required this.id, this.codi, required this.nom, this.formaJuridica, this.sector, this.municipi});

  factory EntitatResum.fromJson(Json j) => EntitatResum(
        id: (j['id'] as num).toInt(),
        codi: j['codi'] as String?,
        nom: j['nom'] as String,
        formaJuridica: _ref(j['forma_juridica']),
        sector: j['sector'] as String?,
        municipi: _ref(j['municipi']),
      );
}

class CentreResum {
  final int id;
  final String? codi;
  final String nom;
  final Ref? tipusCentre;
  final Ref? municipi;
  final String? adreca;
  final String? codiPostal;
  final double? latitud;
  final double? longitud;
  final String? precisioPunt;

  const CentreResum({
    required this.id,
    this.codi,
    required this.nom,
    this.tipusCentre,
    this.municipi,
    this.adreca,
    this.codiPostal,
    this.latitud,
    this.longitud,
    this.precisioPunt,
  });

  bool get tePunt => latitud != null && longitud != null;

  /// Explicació de la precisió del punt (cap és una mesura GPS verificada).
  String? get textPrecisio => switch (precisioPunt) {
        null => null,
        'punt_publicat' => 'Punt publicat per la font oficial (no verificat per GPS).',
        'portal' => 'Ubicació geocodificada a partir de l\'adreça (portal exacte).',
        'portal_proxim' => 'Ubicació aproximada: geocodificada amb el portal veí.',
        'carrer' => 'Ubicació aproximada: punt del carrer (adreça sense número).',
        'toponim' => 'Ubicació geocodificada pel nom del centre.',
        final p => 'Precisió del punt: $p.',
      };

  /// Adreça llegible amb municipi, sense inventar parts que falten.
  String? get adrecaCompleta {
    final parts = [
      if (adreca != null && adreca!.isNotEmpty) adreca!,
      if (municipi != null) [if (codiPostal != null) codiPostal!, municipi!.nom].join(' '),
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  factory CentreResum.fromJson(Json j) => CentreResum(
        id: (j['id'] as num).toInt(),
        codi: j['codi'] as String?,
        nom: j['nom'] as String,
        tipusCentre: _ref(j['tipus_centre']),
        municipi: _ref(j['municipi']),
        adreca: j['adreca'] as String?,
        codiPostal: j['codi_postal'] as String?,
        latitud: _doble(j['latitud']),
        longitud: _doble(j['longitud']),
        precisioPunt: j['precisio_punt'] as String?,
      );
}

class Prestacio {
  final Ref entitat;
  final List<CentreResum> centres;

  const Prestacio({required this.entitat, this.centres = const []});

  factory Prestacio.fromJson(Json j) => Prestacio(
        entitat: Ref.fromJson(Map<String, dynamic>.from(j['entitat'] as Map)),
        centres: _llista(j['centres'], CentreResum.fromJson),
      );
}

class ServeiDetall {
  final int id;
  final String nom;
  final String? descripcio;
  final String? viaAcces;
  final String? cobertura;
  final String? observacions;
  final Font? font;
  final List<Ref> collectius;
  final List<Contacte> contactes;
  final List<Horari> horaris;
  final List<Prestacio> prestacions;

  const ServeiDetall({
    required this.id,
    required this.nom,
    this.descripcio,
    this.viaAcces,
    this.cobertura,
    this.observacions,
    this.font,
    this.collectius = const [],
    this.contactes = const [],
    this.horaris = const [],
    this.prestacions = const [],
  });

  factory ServeiDetall.fromJson(Json j) => ServeiDetall(
        id: (j['id'] as num).toInt(),
        nom: j['nom'] as String,
        descripcio: j['descripcio'] as String?,
        viaAcces: j['via_acces'] as String?,
        cobertura: j['cobertura'] as String?,
        observacions: j['observacions'] as String?,
        font: Font.fromJson(j['font']),
        collectius: _llista(j['collectius'], Ref.fromJson),
        contactes: _llista(j['contactes'], Contacte.fromJson),
        horaris: _llista(j['horaris'], Horari.fromJson),
        prestacions: _llista(j['prestacions'], Prestacio.fromJson),
      );
}

class CentreDetall {
  final CentreResum resum;
  final Font? fontPunt;
  final Ref? titular;
  final Ref? gestor;
  final Font? font;
  final List<Contacte> contactes;
  final List<Horari> horaris;
  final List<ServeiResum> serveis;

  const CentreDetall({
    required this.resum,
    this.fontPunt,
    this.titular,
    this.gestor,
    this.font,
    this.contactes = const [],
    this.horaris = const [],
    this.serveis = const [],
  });

  factory CentreDetall.fromJson(Json j) => CentreDetall(
        resum: CentreResum.fromJson(j),
        fontPunt: Font.fromJson(j['font_punt']),
        titular: _ref(j['titular']),
        gestor: _ref(j['gestor']),
        font: Font.fromJson(j['font']),
        contactes: _llista(j['contactes'], Contacte.fromJson),
        horaris: _llista(j['horaris'], Horari.fromJson),
        serveis: _llista(j['serveis'], ServeiResum.fromJson),
      );
}

class EntitatDetall {
  final int id;
  final String nom;
  final Ref? formaJuridica;
  final String? sector;
  final String? adreca;
  final Ref? municipi;
  final String? codiPostal;
  final Font? font;
  final List<Contacte> contactes;
  final List<Horari> horaris;
  final List<ServeiResum> serveisPrestats;
  final List<CentreResum> centresTitulats;
  final List<CentreResum> centresGestionats;

  const EntitatDetall({
    required this.id,
    required this.nom,
    this.formaJuridica,
    this.sector,
    this.adreca,
    this.municipi,
    this.codiPostal,
    this.font,
    this.contactes = const [],
    this.horaris = const [],
    this.serveisPrestats = const [],
    this.centresTitulats = const [],
    this.centresGestionats = const [],
  });

  factory EntitatDetall.fromJson(Json j) => EntitatDetall(
        id: (j['id'] as num).toInt(),
        nom: j['nom'] as String,
        formaJuridica: _ref(j['forma_juridica']),
        sector: j['sector'] as String?,
        adreca: j['adreca'] as String?,
        municipi: _ref(j['municipi']),
        codiPostal: j['codi_postal'] as String?,
        font: Font.fromJson(j['font']),
        contactes: _llista(j['contactes'], Contacte.fromJson),
        horaris: _llista(j['horaris'], Horari.fromJson),
        serveisPrestats: _llista(j['serveis_prestats'], ServeiResum.fromJson),
        centresTitulats: _llista(j['centres_titulats'], CentreResum.fromJson),
        centresGestionats: _llista(j['centres_gestionats'], CentreResum.fromJson),
      );
}
