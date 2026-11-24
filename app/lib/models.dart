/// Classes que representen el JSON que torna l'API.
library;

class Centre {
  final int id;
  final String nom;
  final String? adreca;
  final String? municipi;
  final String? tipus;
  final double? latitud;
  final double? longitud;

  Centre({
    required this.id,
    required this.nom,
    this.adreca,
    this.municipi,
    this.tipus,
    this.latitud,
    this.longitud,
  });

  factory Centre.fromJson(Map<String, dynamic> json) {
    return Centre(
      id: json['id'],
      nom: json['nom'],
      adreca: json['adreca'],
      municipi: json['municipi'],
      tipus: json['tipus'],
      latitud: (json['latitud'] as num?)?.toDouble(),
      longitud: (json['longitud'] as num?)?.toDouble(),
    );
  }

  /// Només es pot posar al mapa si té les dues coordenades.
  bool get teUbicacio => latitud != null && longitud != null;
}

class Servei {
  final int id;
  final String nom;
  final String? descripcio;
  final List<String> collectius;
  final List<String> municipis;
  final List<String> tipus;

  Servei({
    required this.id,
    required this.nom,
    this.descripcio,
    required this.collectius,
    required this.municipis,
    required this.tipus,
  });

  factory Servei.fromJson(Map<String, dynamic> json) {
    return Servei(
      id: json['id'],
      nom: json['nom'],
      descripcio: json['descripcio'],
      collectius: List<String>.from(json['collectius']),
      municipis: List<String>.from(json['municipis']),
      tipus: List<String>.from(json['tipus']),
    );
  }
}

class Entitat {
  final int id;
  final String nom;
  final String? formaJuridica;
  final String? municipi;

  Entitat({required this.id, required this.nom, this.formaJuridica, this.municipi});

  factory Entitat.fromJson(Map<String, dynamic> json) {
    return Entitat(
      id: json['id'],
      nom: json['nom'],
      formaJuridica: json['forma_juridica'],
      municipi: json['municipi'],
    );
  }
}
