import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';
import 'fitxa_servei.dart';

class FitxaCentre extends StatelessWidget {
  final int id;

  const FitxaCentre(this.id, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Centre')),
      body: ambDades(getFitxa('centres', id), (centre) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(centre['nom'], style: Theme.of(context).textTheme.headlineSmall),
            dada('Tipus', centre['tipus']),
            dada('Adreça', centre['adreca']),
            dada('Municipi', centre['municipi']),
            dada('Titular', centre['titular']),
            dada('Gestor', centre['gestor']),
            if (centre['latitud'] == null) const Text('Aquest centre no té ubicació al mapa.'),
            Seccio('Contactes', contactes(centre['contactes'])),
            Seccio('Horaris', [for (final h in centre['horaris']) Text(h)]),
            Seccio('Serveis que s\'hi fan', [
              for (final s in centre['serveis'])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s['nom']),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => obri(context, FitxaServei(s['id'])),
                ),
            ]),
          ],
        );
      }),
    );
  }
}
