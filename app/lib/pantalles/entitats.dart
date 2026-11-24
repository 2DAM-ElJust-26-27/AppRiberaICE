import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../widgets.dart';
import 'fitxa_entitat.dart';

/// Pestanya Entitats: llista de les organitzacions.
class PantallaEntitats extends StatefulWidget {
  const PantallaEntitats({super.key});

  @override
  State<PantallaEntitats> createState() => _PantallaEntitatsState();
}

class _PantallaEntitatsState extends State<PantallaEntitats> {
  final Future<List<Entitat>> _entitats = getEntitats();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entitats')),
      body: ambDades(_entitats, (entitats) {
        return ListView(
          children: [
            for (final e in entitats)
              ListTile(
                leading: const Icon(Icons.apartment),
                title: Text(e.nom),
                subtitle: Text([e.formaJuridica, e.municipi].where((x) => x != null).join(' · ')),
                onTap: () => obri(context, FitxaEntitat(e.id)),
              ),
          ],
        );
      }),
    );
  }
}
