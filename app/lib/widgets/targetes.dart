import 'package:flutter/material.dart';

import '../models/models.dart';
import '../pantalles/detall_centre.dart';
import '../pantalles/detall_servei.dart';
import 'comuns.dart';

void obriServei(BuildContext context, int id) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetallServei(id: id)));

void obriCentre(BuildContext context, int id) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetallCentre(id: id)));

/// Targeta d'un servei a la llista del directori.
class TargetaServei extends StatelessWidget {
  final ServeiResum servei;

  const TargetaServei(this.servei, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = servei;
    final sub = t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => obriServei(context, s.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.nom, style: t.textTheme.titleMedium),
            if (s.entitats.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.apartment_outlined, size: 16, color: t.colorScheme.outline),
                const SizedBox(width: 6),
                Expanded(child: Text(s.entitats.map((e) => e.nom).join(' · '), style: sub)),
              ]),
            ],
            if (s.municipis.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.place_outlined, size: 16, color: t.colorScheme.outline),
                const SizedBox(width: 6),
                Expanded(child: Text('Es presta a ${s.municipis.map((m) => m.nom).join(', ')}', style: sub)),
              ]),
            ],
            if (s.collectius.isNotEmpty) ...[
              const SizedBox(height: 10),
              XipsCollectius(s.collectius, maxim: 3),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Targeta d'un centre a la llista del directori.
class TargetaCentre extends StatelessWidget {
  final CentreResum centre;

  const TargetaCentre(this.centre, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = centre;
    final sub = t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => obriCentre(context, c.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              backgroundColor: t.colorScheme.primaryContainer,
              foregroundColor: t.colorScheme.onPrimaryContainer,
              child: const Icon(Icons.home_work_outlined),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.nom, style: t.textTheme.titleMedium),
                if (c.tipusCentre != null) Text(c.tipusCentre!.nom, style: sub),
                if (c.adrecaCompleta != null) ...[
                  const SizedBox(height: 4),
                  Text(c.adrecaCompleta!, style: sub),
                ],
              ]),
            ),
            if (c.tePunt) Tooltip(message: 'Té ubicació al mapa', child: Icon(Icons.map_outlined, color: t.colorScheme.primary)),
          ]),
        ),
      ),
    );
  }
}
