part of 'models.dart';

class CentreResum {
  final int id;
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
