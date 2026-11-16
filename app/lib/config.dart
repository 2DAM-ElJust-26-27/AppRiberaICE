/// Configuració del client.
///
/// L'URL de l'API es pot canviar en compilar:
///   flutter run -d chrome --dart-define=API_URL=http://localhost:8080
/// Exemples:
///   - Navegador (Flutter web): http://localhost:8080  (per defecte)
///   - Emulador Android:        http://10.0.2.2:8080
///   - Mòbil físic:             http://IP-DEL-PC:8080
class Config {
  Config._();

  static const String urlApi = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080');
}
