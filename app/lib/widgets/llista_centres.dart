import 'package:flutter/material.dart';

import '../models/models.dart';
import 'comuns.dart';

/// Llista de centres de la pestanya Centres. Es fa servir dins del panell
/// lateral (pantalla gran) i del full inferior (mòbil).
class LlistaCentres extends StatelessWidget {
  final List<CentreResum> centres;
  final bool carregant;
  final CentreResum? seleccionat;
  final bool filtresActius;
  final ValueChanged<CentreResum> onTria;
  final ValueChanged<CentreResum> onFitxa;
  final VoidCallback onNeteja;

  /// Si no és null, la capçalera mostra una X per tancar la llista.
  final VoidCallback? onTanca;
  final ScrollController? scroll;

  const LlistaCentres({
    super.key,
    required this.centres,
    required this.carregant,
    required this.seleccionat,
    required this.filtresActius,
    required this.onTria,
    required this.onFitxa,
    required this.onNeteja,
    this.onTanca,
    this.scroll,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final ambPunt = centres.where((c) => c.tePunt).length;
    final buit = carregant && centres.isEmpty;

    final capcalera = Padding(
      padding: EdgeInsets.fromLTRB(16, onTanca != null ? 12 : 0, 4, 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(buit ? 'Carregant centres…' : '${centres.length} ${centres.length == 1 ? 'centre' : 'centres'}',
                style: t.textTheme.titleMedium),
            if (!buit && centres.isNotEmpty)
              Text(
                ambPunt == centres.length
                    ? 'Tots apareixen al mapa'
                    : '$ambPunt al mapa · ${centres.length - ambPunt} sense coordenades (toca per vore la fitxa)',
                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
          ]),
        ),
        if (onTanca != null) IconButton(tooltip: 'Tanca la llista', icon: const Icon(Icons.close), onPressed: onTanca),
      ]),
    );

    return CustomScrollView(controller: scroll, slivers: [
      SliverToBoxAdapter(child: capcalera),
      if (buit)
        const SliverToBoxAdapter(child: Carregant())
      else if (centres.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const Nota('Cap centre coincideix amb aquests filtres. Pot ser que el servei no tinga cap centre associat '
                  '(la ubicació pot ser desconeguda) o que no hi haja dades.'),
              if (filtresActius) TextButton(onPressed: onNeteja, child: const Text('Neteja els filtres')),
            ]),
          ),
        )
      else
        SliverList.builder(
          itemCount: centres.length,
          itemBuilder: (context, i) {
            final c = centres[i];
            return ListTile(
              selected: c == seleccionat,
              leading: Icon(c.tePunt ? Icons.location_on : Icons.location_off_outlined,
                  color: c.tePunt ? t.colorScheme.primary : t.colorScheme.outline),
              title: Text(c.nom),
              subtitle: Text([if (c.tipusCentre != null) c.tipusCentre!.nom, if (c.municipi != null) c.municipi!.nom].join(' · ')),
              trailing: IconButton(tooltip: 'Obri la fitxa', icon: const Icon(Icons.chevron_right), onPressed: () => onFitxa(c)),
              onTap: () => onTria(c),
            );
          },
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ]);
  }
}
