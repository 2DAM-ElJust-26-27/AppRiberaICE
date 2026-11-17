import 'package:flutter/material.dart';

import '../dades/api_ribera.dart';
import '../models/models.dart';
import 'assistent.dart';
import 'centres_mapa.dart';
import 'entitats.dart';

/// Pantalla principal amb tres pestanyes:
///  - Centres (primera en obrir l'app): mapa amb filtres de serveis
///  - Serveis: assistent guiat «Carlos Collado»
///  - Entitats: llista d'entitats
///
/// Guarda amb `setState` la pestanya oberta i els catàlegs (municipis,
/// col·lectius, tipus de centre), que passa a les pestanyes pel constructor.
class PantallaInici extends StatefulWidget {
  const PantallaInici({super.key});

  @override
  State<PantallaInici> createState() => _PantallaIniciState();
}

class _PantallaIniciState extends State<PantallaInici> {
  static const _destins = [
    (Icons.map_outlined, Icons.map, 'Centres'),
    (Icons.support_agent_outlined, Icons.support_agent, 'Serveis'),
    (Icons.apartment_outlined, Icons.apartment, 'Entitats'),
  ];

  int _pestanya = 0; // 0 = Centres, 1 = Serveis, 2 = Entitats

  List<Municipi> _municipis = [];
  Catalegs _catalegs = const Catalegs();
  EstatCarrega _estatCatalegs = EstatCarrega.carregant;

  /// Filtres que l'assistent envia al mapa («Vore on es presten al mapa»).
  Filtres? _filtresPerAlMapa;

  @override
  void initState() {
    super.initState();
    _carregaCatalegs();
  }

  Future<void> _carregaCatalegs() async {
    try {
      final municipis = await apiRibera.municipis();
      final catalegs = await apiRibera.catalegs();
      setState(() {
        _municipis = municipis;
        _catalegs = catalegs;
        _estatCatalegs = EstatCarrega.llest;
      });
    } catch (_) {
      setState(() => _estatCatalegs = EstatCarrega.error);
    }
  }

  /// L'assistent demana mostrar uns filtres al mapa: canviem a la pestanya Centres.
  void _veureAlMapa(Filtres filtres) {
    setState(() {
      _filtresPerAlMapa = filtres;
      _pestanya = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final ample = MediaQuery.sizeOf(context).width >= 840;

    // IndexedStack manté viva cada pestanya (no es perd el mapa ni la conversa en canviar).
    final cos = IndexedStack(
      index: _pestanya,
      children: [
        PantallaCentres(
          municipis: _municipis,
          catalegs: _catalegs,
          catalegsCarregats: _estatCatalegs == EstatCarrega.llest,
          filtresExterns: _filtresPerAlMapa,
        ),
        PantallaAssistent(onVeureAlMapa: _veureAlMapa),
        const PantallaEntitats(),
      ],
    );
    void canvia(int i) => setState(() => _pestanya = i);

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
                selectedIndex: _pestanya,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: canvia,
                destinations: [
                  for (final d in _destins)
                    NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: cos),
            ])
          : cos,
      bottomNavigationBar: ample
          ? null
          : NavigationBar(
              selectedIndex: _pestanya,
              onDestinationSelected: canvia,
              destinations: [
                for (final d in _destins) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
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
            'L\'assistent «Carlos Collado» no és una intel·ligència artificial: fa preguntes guiades sobre les dades del directori.\n\n'
            'Cartografia: © col·laboradors d\'OpenStreetMap. Ubicacions: CartoCiudad (IGN/CNIG), geocodificades a partir de les adreces.'),
      ],
    );
  }
}
