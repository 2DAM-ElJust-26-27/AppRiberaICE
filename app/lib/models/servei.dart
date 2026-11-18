part of 'models.dart';

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
