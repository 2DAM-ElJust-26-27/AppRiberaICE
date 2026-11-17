import 'package:flutter/material.dart';

import '../dades/api_ribera.dart';
import '../models/models.dart';
import '../widgets/comuns.dart';
import '../widgets/contactes.dart';
import 'detall_centre.dart';
import 'detall_comu.dart';
import 'detall_entitat.dart';

/// Fitxa d'un servei: col·lectius, contactes, horaris i qui el presta i on.
class DetallServei extends StatelessWidget {
  final int id;

  const DetallServei({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return FitxaFutura<ServeiDetall>(
      titol: 'Servei',
      carrega: () => apiRibera.servei(id),
      construeix: (context, s) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CapcaleraFitxa(icona: Icons.volunteer_activism_outlined, titol: s.nom, subtitol: s.descripcio),
        if (s.collectius.isNotEmpty)
          Seccio(titol: 'Adreçat a', icona: Icons.groups_outlined, fills: [
            XipsCollectius(s.collectius),
            const Nota('Col·lectius documentals: no són una garantia d\'admissió.'),
          ]),
        if (s.viaAcces != null || s.cobertura != null || s.observacions != null)
          Seccio(titol: 'Informació', icona: Icons.description_outlined, fills: [
            if (s.viaAcces != null) Dada('Via d\'accés', s.viaAcces!),
            if (s.cobertura != null) Dada('Cobertura', s.cobertura!),
            if (s.observacions != null) Dada('Observacions', s.observacions!),
          ]),
        Seccio(titol: 'Qui el presta i on', icona: Icons.apartment_outlined, fills: [
          if (s.prestacions.isEmpty) const Nota('No consta l\'entitat prestadora d\'aquest servei.'),
          for (final p in s.prestacions) _Prestacio(p),
        ]),
        Seccio(titol: 'Contacte', icona: Icons.call_outlined, fills: [LlistaContactes(s.contactes)]),
        Seccio(titol: 'Horari', icona: Icons.schedule, fills: [LlistaHoraris(s.horaris)]),
        if (s.font != null) Seccio(titol: 'Procedència', icona: Icons.source_outlined, fills: [TextFont(s.font)]),
      ]),
    );
  }
}

class _Prestacio extends StatelessWidget {
  final Prestacio p;

  const _Prestacio(this.p);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(children: [
        ListTile(
          leading: const Icon(Icons.apartment),
          title: Text(p.entitat.nom),
          subtitle: const Text('Entitat prestadora'),
          trailing: const Icon(Icons.chevron_right),
          onTap: p.entitat.id == null
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetallEntitat(id: p.entitat.id!))),
        ),
        if (p.centres.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text('Centre no especificat (la ubicació pot ser desconeguda).',
                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          ),
        for (final c in p.centres)
          ListTile(
            dense: true,
            leading: const Icon(Icons.home_work_outlined),
            title: Text(c.nom),
            subtitle: c.adrecaCompleta == null ? null : Text(c.adrecaCompleta!),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetallCentre(id: c.id))),
          ),
      ]),
    );
  }
}
