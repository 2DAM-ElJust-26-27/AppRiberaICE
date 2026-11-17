import 'package:flutter/material.dart';

import '../estat/estat_app.dart';
import 'assistent.dart';
import 'centres_mapa.dart';
import 'entitats.dart';

/// Pantalla principal amb tres pestanyes:
///  - Centres (primera en obrir l'app): mapa amb filtres de serveis
///  - Serveis: assistent guiat «Carlos Collado»
///  - Entitats: llista d'entitats
class PantallaInici extends StatelessWidget {
  const PantallaInici({super.key});

  static const _destins = [
    (Pestanya.centres, Icons.map_outlined, Icons.map, 'Centres'),
    (Pestanya.serveis, Icons.support_agent_outlined, Icons.support_agent, 'Serveis'),
    (Pestanya.entitats, Icons.apartment_outlined, Icons.apartment, 'Entitats'),
  ];

  @override
  Widget build(BuildContext context) {
    final estat = EstatApp.of(context);
    final t = Theme.of(context);
    final ample = MediaQuery.sizeOf(context).width >= 840;

    return ValueListenableBuilder<Pestanya>(
      valueListenable: estat.pestanya,
      builder: (context, actual, _) {
        final index = actual.index;
        final cos = IndexedStack(
          index: index,
          children: const [PantallaCentres(), PantallaAssistent(), PantallaEntitats()],
        );
        void canvia(int i) => estat.pestanya.value = Pestanya.values[i];

        return Scaffold(
          appBar: AppBar(
            title: Row(children: [
              Icon(Icons.hub_outlined, color: t.colorScheme.primary),
              const SizedBox(width: 10),
              const Text('Connectant la Ribera'),
            ]),
            actions: [
              IconButton(tooltip: 'Quant a les dades', icon: const Icon(Icons.info_outline), onPressed: () => _quantA(context)),
            ],
          ),
          body: ample
              ? Row(children: [
                  NavigationRail(
                    selectedIndex: index,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: canvia,
                    destinations: [
                      for (final d in _destins)
                        NavigationRailDestination(icon: Icon(d.$2), selectedIcon: Icon(d.$3), label: Text(d.$4)),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: cos),
                ])
              : cos,
          bottomNavigationBar: ample
              ? null
              : NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: canvia,
                  destinations: [
                    for (final d in _destins) NavigationDestination(icon: Icon(d.$2), selectedIcon: Icon(d.$3), label: d.$4),
                  ],
                ),
        );
      },
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
            'L\'assistent «Carlos Collado» no és una intel·ligència artificial: fa preguntes guiades sobre les dades del directori.\n\n'
            'Cartografia: © col·laboradors d\'OpenStreetMap. Ubicacions: CartoCiudad (IGN/CNIG), geocodificades a partir de les adreces.'),
      ],
    );
  }
}
