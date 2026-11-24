import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';
import 'fitxa_centre.dart';
import 'fitxa_entitat.dart';

class FitxaServei extends StatelessWidget {
  final int id;

  const FitxaServei(this.id, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Servei')),
      body: ambDades(getFitxa('serveis', id), (servei) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(servei['nom'], style: Theme.of(context).textTheme.headlineSmall),
            dada('Descripció', servei['descripcio']),
            dada('Com s\'hi accedeix', servei['via_acces']),
            dada('Cobertura', servei['cobertura']),
            dada('Observacions', servei['observacions']),
            Seccio('Per a qui és', [
              Wrap(spacing: 8, children: [for (final c in servei['collectius']) Chip(label: Text(c))]),
            ]),
            Seccio('Contactes', contactes(servei['contactes'])),
            Seccio('Horaris', [for (final h in servei['horaris']) Text(h)]),
            Seccio('Qui el presta', [
              for (final e in servei['entitats'])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(e['nom']),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => obri(context, FitxaEntitat(e['id'])),
                ),
            ]),
            Seccio('On es fa', [
              for (final c in servei['centres'])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(c['nom']),
                  subtitle: Text(c['municipi'] ?? ''),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => obri(context, FitxaCentre(c['id'])),
                ),
            ]),
          ],
        );
      }),
    );
  }
}
