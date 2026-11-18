import 'package:flutter/material.dart';

import '../dades/api_ribera.dart';

/// Barra superior: botó de filtres i xips dels filtres actius (es poden llevar d'un en un).
class BarraFiltres extends StatelessWidget {
  final Filtres filtres;
  final bool actiu;
  final String? nomServei, nomCollectiu, nomMunicipi, nomTipus;
  final VoidCallback onObriFiltres;
  final ValueChanged<Filtres> onCanvia;
  final VoidCallback onNeteja;

  const BarraFiltres({super.key,
    required this.filtres,
    required this.actiu,
    required this.nomServei,
    required this.nomCollectiu,
    required this.nomMunicipi,
    required this.nomTipus,
    required this.onObriFiltres,
    required this.onCanvia,
    required this.onNeteja,
  });

  @override
  Widget build(BuildContext context) {
    final f = filtres;
    final t = Theme.of(context);

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Badge(
            isLabelVisible: f.actius,
            label: Text('${f.nombreActius}'),
            child: FilledButton.tonalIcon(
              onPressed: actiu ? onObriFiltres : null,
              icon: const Icon(Icons.tune),
              label: const Text('Filtra per servei'),
            ),
          ),
          const SizedBox(width: 8),
          if (!f.actius)
            Center(
              child: Text('Mostrant tots els centres',
                  style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            ),
          if (f.serveiId != null)
            _Xip(Icons.volunteer_activism_outlined, nomServei ?? 'Servei', () => onCanvia(f.copyWith(serveiId: () => null))),
          if (f.collectiu != null)
            _Xip(Icons.groups_outlined, nomCollectiu ?? '', () => onCanvia(f.copyWith(collectiu: () => null))),
          if (f.municipiId != null)
            _Xip(Icons.place_outlined, nomMunicipi ?? '', () => onCanvia(f.copyWith(municipiId: () => null))),
          if (f.tipusCentre != null)
            _Xip(Icons.home_work_outlined, nomTipus ?? '', () => onCanvia(f.copyWith(tipusCentre: () => null))),
          if (f.actius) TextButton(onPressed: onNeteja, child: const Text('Neteja-ho tot')),
        ],
      ),
    );
  }
}

class _Xip extends StatelessWidget {
  final IconData icona;
  final String text;
  final VoidCallback lleva;

  const _Xip(this.icona, this.text, this.lleva);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InputChip(
          avatar: Icon(icona, size: 18),
          label: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220), child: Text(text, overflow: TextOverflow.ellipsis)),
          onDeleted: lleva,
        ),
      );
}

// ------------------------------------------------------------------ mapa
