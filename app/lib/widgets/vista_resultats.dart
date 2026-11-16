import 'package:flutter/material.dart';

import '../estat/directori_estat.dart';
import 'comuns.dart';

/// Estructura comuna per a les llistes: càrrega, error, buit i resultats.
class VistaResultats extends StatelessWidget {
  final DirectoriEstat estat;
  final bool buit;
  final String textBuit;
  final int itemCount;
  final Widget Function(int) itemBuilder;

  const VistaResultats({
    super.key,
    required this.estat,
    required this.buit,
    required this.textBuit,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (estat.estatResultats == EstatCarrega.error) {
      return MissatgeEstat.error(estat.error ?? '', estat.carrega);
    }
    if (estat.estatResultats != EstatCarrega.llest && buit) return const Carregant();
    if (buit) {
      return MissatgeEstat(
        icona: Icons.search_off,
        titol: 'No hi ha resultats',
        text: textBuit,
        accio: estat.filtres.actius ? 'Neteja els filtres' : null,
        onAccio: estat.netejaFiltres,
      );
    }
    return Stack(children: [
      RefreshIndicator(
        onRefresh: estat.carrega,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: itemCount,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => itemBuilder(i),
        ),
      ),
      if (estat.estatResultats == EstatCarrega.carregant) const LinearProgressIndicator(),
    ]);
  }
}
