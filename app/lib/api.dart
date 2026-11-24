import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Adreça de l'API. Es pot canviar en arrancar:
///   flutter run -d chrome --dart-define=API_URL=http://localhost:8080
/// (emulador Android: http://10.0.2.2:8080)
const String urlApi = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080');

/// Fa una petició GET i torna el JSON ja convertit.
Future<dynamic> _get(String ruta) async {
  final resposta = await http.get(Uri.parse('$urlApi$ruta'));
  if (resposta.statusCode != 200) {
    throw Exception('Error ${resposta.statusCode}');
  }
  return jsonDecode(utf8.decode(resposta.bodyBytes));
}

/// Tots els centres, o només els d'un servei si es passa [serveiId].
Future<List<Centre>> getCentres({int? serveiId}) async {
  final ruta = serveiId == null ? '/api/centres' : '/api/centres?servei=$serveiId';
  final List dades = await _get(ruta);
  return dades.map((json) => Centre.fromJson(json)).toList();
}

Future<List<Servei>> getServeis() async {
  final List dades = await _get('/api/serveis');
  return dades.map((json) => Servei.fromJson(json)).toList();
}

Future<List<Entitat>> getEntitats() async {
  final List dades = await _get('/api/entitats');
  return dades.map((json) => Entitat.fromJson(json)).toList();
}

/// Fitxa completa. [tipus] és 'centres', 'serveis' o 'entitats'.
Future<Map<String, dynamic>> getFitxa(String tipus, int id) async {
  return await _get('/api/$tipus/$id');
}
