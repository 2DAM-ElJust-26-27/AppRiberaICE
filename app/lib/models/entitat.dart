part of 'models.dart';

class EntitatResum {
  final int id;
  final String nom;
  final Ref? formaJuridica;
  final String? sector;
  final Ref? municipi;

  const EntitatResum({required this.id, required this.nom, this.formaJuridica, this.sector, this.municipi});

  factory EntitatResum.fromJson(Json j) => EntitatResum(
        id: (j['id'] as num).toInt(),
        nom: j['nom'] as String,
        formaJuridica: _ref(j['forma_juridica']),
        sector: j['sector'] as String?,
        municipi: _ref(j['municipi']),
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
