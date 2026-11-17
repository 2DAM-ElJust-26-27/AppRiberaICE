import 'package:flutter/material.dart';

import '../models/models.dart';
import '../navegacio.dart';
import 'comuns.dart';

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
