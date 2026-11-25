import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Obri una pantalla nova damunt de l'actual.
void obri(BuildContext context, Widget pantalla) {
  Navigator.push(context, MaterialPageRoute(builder: (context) => pantalla));
}

/// Espera unes dades de l'API: mentre arriben mostra un cercle,
/// i si falla mostra un missatge d'error.

/// T -> recibe Servei, Entitat, Center...
Widget ambDades<T>(Future<T> futur, Widget Function(T dades) construeix) {
  return FutureBuilder<T>(
    future: futur,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No s\'ha pogut connectar amb l\'API. Està arrancat Docker?', textAlign: TextAlign.center),
          ),
        );
      }
      if (!snapshot.hasData) {  /// contiene información sobre el estado de la petición a la API
        return const Center(child: CircularProgressIndicator());
      }
      return construeix(snapshot.data as T);
    },
  );
}

/// Títol d'una secció d'una fitxa i el seu contingut.
class Seccio extends StatelessWidget {
  final String titol;
  final List<Widget> fills;

  const Seccio(this.titol, this.fills, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(titol, style: Theme.of(context).textTheme.titleMedium),
        if (fills.isEmpty) const Text('No consta', style: TextStyle(color: Colors.grey)),
        ...fills,
      ],
    );
  }
}

/// Una dada de la fitxa (p. ex. «Adreça: ...»). Si el valor és null, no es mostra res.
Widget dada(String etiqueta, Object? valor) {
  if (valor == null) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text('$etiqueta: $valor'),
  );
}

/// Telèfons, correus i webs. En tocar-los s'obri l'aplicació corresponent.
List<Widget> contactes(List contactes) {
  return [
    for (final c in contactes)
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(_icona(c['tipus'])),
        title: Text(c['valor']),
        onTap: () => launchUrl(_enllac(c['tipus'], c['valor'])),
      ),
  ];
}

IconData _icona(String tipus) {
  if (tipus == 'telèfon') return Icons.phone;
  if (tipus == 'correu') return Icons.mail;
  return Icons.language;
}

Uri _enllac(String tipus, String valor) {
  if (tipus == 'telèfon') return Uri.parse('tel:${valor.replaceAll(' ', '')}');
  if (tipus == 'correu') return Uri.parse('mailto:$valor');
  return Uri.parse(valor.startsWith('http') ? valor : 'https://$valor');
}
