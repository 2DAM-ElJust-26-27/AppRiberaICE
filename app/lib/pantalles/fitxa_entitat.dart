import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';
import 'fitxa_centre.dart';
import 'fitxa_servei.dart';

class FitxaEntitat extends StatelessWidget {
  final int id;

  const FitxaEntitat(this.id, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entitat')),
      body: ambDades(getFitxa('entitats', id), (entitat) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(entitat['nom'], style: Theme.of(context).textTheme.headlineSmall),
            dada('Forma jurídica', entitat['forma_juridica']),
            dada('Sector', entitat['sector']),
            dada('Adreça', entitat['adreca']),
            dada('Municipi', entitat['municipi']),
            Seccio('Contactes', contactes(entitat['contactes'])),
            Seccio('Horaris', [for (final h in entitat['horaris']) Text(h)]),
            Seccio('Serveis que presta', [
              for (final s in entitat['serveis'])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s['nom']),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => obri(context, FitxaServei(s['id'])),
                ),
            ]),
            Seccio('Centres', [
              for (final c in entitat['centres'])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(c['nom']),
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
