import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/models.dart';

/// Error en comunicar amb l'API, amb un missatge llegible per a l'usuari.
class ErrorApi implements Exception {
  final String missatge;
  const ErrorApi(this.missatge);

  @override
  String toString() => missatge;
}

/// Filtres combinables del directori. Tots són opcionals.
class Filtres {
  final String text;
  final int? municipiId;
  final String? collectiu; // codi (COL_…)
  final String? tipusCentre; // codi (TC…)

  const Filtres({this.text = '', this.municipiId, this.collectiu, this.tipusCentre});

  bool get actius => municipiId != null || collectiu != null || tipusCentre != null;
  int get nombreActius => [municipiId, collectiu, tipusCentre].where((e) => e != null).length;

  Filtres copyWith({
    String? text,
    int? Function()? municipiId,
    String? Function()? collectiu,
    String? Function()? tipusCentre,
  }) =>
      Filtres(
        text: text ?? this.text,
        municipiId: municipiId != null ? municipiId() : this.municipiId,
        collectiu: collectiu != null ? collectiu() : this.collectiu,
        tipusCentre: tipusCentre != null ? tipusCentre() : this.tipusCentre,
      );

  Map<String, String> get parametres => {
        if (text.trim().isNotEmpty) 'q': text.trim(),
        if (municipiId != null) 'municipi': '$municipiId',
        if (collectiu != null) 'collectiu': collectiu!,
        if (tipusCentre != null) 'tipus_centre': tipusCentre!,
      };
}

/// Client HTTP de l'API REST de Connectant la Ribera (només lectura).
class ApiRibera {
  final String base;
  final http.Client _client;

  ApiRibera({String? base, http.Client? client})
      : base = base ?? Config.urlApi,
        _client = client ?? http.Client();

  Future<dynamic> _get(String ruta, [Map<String, String>? params]) async {
    final uri = Uri.parse('$base/api/$ruta').replace(queryParameters: (params?.isEmpty ?? true) ? null : params);
    final http.Response r;
    try {
      r = await _client.get(uri).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ErrorApi('No s\'ha pogut connectar amb el servidor ($base). Comprova que l\'API està en marxa.');
    }
    final cos = utf8.decode(r.bodyBytes);
    if (r.statusCode == 404) throw const ErrorApi('No s\'ha trobat la fitxa sol·licitada.');
    if (r.statusCode != 200) {
      String msg = 'Error del servidor (${r.statusCode}).';
      try {
        msg = (jsonDecode(cos) as Map)['error'] as String? ?? msg;
      } catch (_) {}
      throw ErrorApi(msg);
    }
    try {
      return jsonDecode(cos);
    } catch (_) {
      throw const ErrorApi('Les dades rebudes no coincideixen amb el format del directori.');
    }
  }

  List<T> _llista<T>(dynamic d, T Function(Json) f) {
    if (d is! List) throw const ErrorApi('Les dades rebudes no coincideixen amb el format del directori.');
    return d.map((e) => f(Map<String, dynamic>.from(e as Map))).toList();
  }

  Json _objecte(dynamic d) {
    if (d is! Map) throw const ErrorApi('La fitxa rebuda no coincideix amb el format del directori.');
    return Map<String, dynamic>.from(d);
  }

  Future<List<Municipi>> municipis() async => _llista(await _get('municipis'), Municipi.fromJson);

  Future<Catalegs> catalegs() async => Catalegs.fromJson(_objecte(await _get('catalegs')));

  Future<List<ServeiResum>> serveis(Filtres f) async =>
      _llista(await _get('serveis', f.parametres), ServeiResum.fromJson);

  Future<List<CentreResum>> centres(Filtres f, {bool nomesAmbPunt = false}) async => _llista(
        await _get('centres', {...f.parametres, if (nomesAmbPunt) 'amb_punt': 'true'}),
        CentreResum.fromJson,
      );

  Future<ServeiDetall> servei(int id) async => ServeiDetall.fromJson(_objecte(await _get('serveis/$id')));

  Future<CentreDetall> centre(int id) async => CentreDetall.fromJson(_objecte(await _get('centres/$id')));

  Future<EntitatDetall> entitat(int id) async => EntitatDetall.fromJson(_objecte(await _get('entitats/$id')));
}
