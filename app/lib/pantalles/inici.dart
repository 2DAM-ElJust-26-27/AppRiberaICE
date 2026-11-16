import 'package:flutter/material.dart';

import '../estat/directori_estat.dart';
import '../widgets/full_filtres.dart';
import 'llista_centres.dart';
import 'llista_serveis.dart';
import 'mapa.dart';

/// Pantalla principal: cerca, filtres i tres vistes (serveis, centres, mapa).
class PantallaInici extends StatefulWidget {
  const PantallaInici({super.key});

  @override
  State<PantallaInici> createState() => _PantallaIniciState();
}

class _PantallaIniciState extends State<PantallaInici> {
  int _pestanya = 0;
  final _cerca = TextEditingController();

  @override
  void dispose() {
    _cerca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estat = EstatDirectori.of(context);
    final t = Theme.of(context);
    final ample = MediaQuery.sizeOf(context).width >= 840;

    final vistes = const [LlistaServeis(), LlistaCentres(), VistaMapa()];
    final destins = [
      (Icons.volunteer_activism_outlined, Icons.volunteer_activism, 'Serveis', estat.serveis.length),
      (Icons.home_work_outlined, Icons.home_work, 'Centres', estat.centres.length),
      (Icons.map_outlined, Icons.map, 'Mapa', estat.punts.length),
    ];

    final contingut = Column(children: [
      _BarraCerca(controlador: _cerca),
      _FiltresActius(),
      Expanded(child: vistes[_pestanya]),
    ]);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Icon(Icons.hub_outlined, color: t.colorScheme.primary),
          const SizedBox(width: 10),
          const Text('Connectant la Ribera'),
        ]),
        actions: [
          IconButton(
            tooltip: 'Quant a les dades',
            icon: const Icon(Icons.info_outline),
            onPressed: () => _quantA(context),
          ),
        ],
      ),
      body: ample
          ? Row(children: [
              NavigationRail(
                selectedIndex: _pestanya,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: (i) => setState(() => _pestanya = i),
                destinations: [
                  for (final d in destins)
                    NavigationRailDestination(
                      icon: Badge(label: Text('${d.$4}'), isLabelVisible: estat.estatResultats == EstatCarrega.llest, child: Icon(d.$1)),
                      selectedIcon: Icon(d.$2),
                      label: Text(d.$3),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000), child: contingut))),
            ])
          : contingut,
      bottomNavigationBar: ample
          ? null
          : NavigationBar(
              selectedIndex: _pestanya,
              onDestinationSelected: (i) => setState(() => _pestanya = i),
              destinations: [
                for (final d in destins)
                  NavigationDestination(
                    icon: Badge(label: Text('${d.$4}'), isLabelVisible: estat.estatResultats == EstatCarrega.llest, child: Icon(d.$1)),
                    selectedIcon: Icon(d.$2),
                    label: d.$3,
                  ),
              ],
            ),
    );
  }

  void _quantA(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Connectant la Ribera',
      applicationVersion: 'Sprint 1',
      children: const [
        Text('Directori comarcal de serveis socials i comunitaris de la Ribera Alta i la Ribera Baixa.\n\n'
            'Les dades són un conjunt inicial docent procedent de recull i de fonts identificades: no és un cens exhaustiu '
            'ni un directori oficial. Les adreces, els col·lectius i els horaris requereixen revisió i no garanteixen admissió.\n\n'
            'Cartografia: © col·laboradors d\'OpenStreetMap.'),
      ],
    );
  }
}

class _BarraCerca extends StatelessWidget {
  final TextEditingController controlador;

  const _BarraCerca({required this.controlador});

  @override
  Widget build(BuildContext context) {
    final estat = EstatDirectori.of(context);
    final n = estat.filtres.nombreActius;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: controlador,
            onChanged: estat.cerca,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Busca per nom o necessitat',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: estat.filtres.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Esborra la cerca',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        controlador.clear();
                        estat.cerca('');
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Badge(
          isLabelVisible: n > 0,
          label: Text('$n'),
          child: IconButton.filledTonal(
            tooltip: 'Filtres',
            icon: const Icon(Icons.tune),
            onPressed: estat.estatCatalegs == EstatCarrega.llest ? () => mostraFiltres(context) : null,
          ),
        ),
      ]),
    );
  }
}

class _FiltresActius extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final e = EstatDirectori.of(context);
    final f = e.filtres;
    if (!f.actius) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (f.municipiId != null)
            _Xip(Icons.place_outlined, e.nomMunicipi(f.municipiId) ?? '', () => e.aplica(f.copyWith(municipiId: () => null))),
          if (f.collectiu != null)
            _Xip(Icons.groups_outlined, e.nomCataleg(e.catalegs.collectius, f.collectiu) ?? '',
                () => e.aplica(f.copyWith(collectiu: () => null))),
          if (f.tipusCentre != null)
            _Xip(Icons.home_work_outlined, e.nomCataleg(e.catalegs.tipusCentre, f.tipusCentre) ?? '',
                () => e.aplica(f.copyWith(tipusCentre: () => null))),
          TextButton(onPressed: e.netejaFiltres, child: const Text('Neteja-ho tot')),
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
        child: InputChip(avatar: Icon(icona, size: 18), label: Text(text), onDeleted: lleva),
      );
}
