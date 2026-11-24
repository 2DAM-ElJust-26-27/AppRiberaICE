import 'package:flutter/material.dart';

import 'pantalles/assistent.dart';
import 'pantalles/centres.dart';
import 'pantalles/entitats.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Connectant la Ribera',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF2E7D5B), useMaterial3: true),
      home: const Inici(),
    );
  }
}

/// Pantalla principal amb les tres pestanyes.
class Inici extends StatefulWidget {
  const Inici({super.key});

  @override
  State<Inici> createState() => _IniciState();
}

class _IniciState extends State<Inici> {
  int _pestanya = 0;

  @override
  Widget build(BuildContext context) {
    // IndexedStack manté les pestanyes vives: en tornar, no es tornen a carregar
    final pantalla = IndexedStack(
      index: _pestanya,
      children: const [PantallaCentres(), PantallaAssistent(), PantallaEntitats()],
    );

    // Pantalla gran (ordinador): barra vertical a la dreta
    if (MediaQuery.of(context).size.width >= 840) {
      return Scaffold(
        body: Row(
          children: [
            Expanded(child: pantalla),
            const VerticalDivider(width: 1),
            NavigationRail(
              selectedIndex: _pestanya,
              onDestinationSelected: (i) => setState(() => _pestanya = i),
              labelType: NavigationRailLabelType.all,
              groupAlignment: 0,  // botons centrats en vertical
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.map), label: Text('Centres')),
                NavigationRailDestination(icon: Icon(Icons.support_agent), label: Text('Serveis')),
                NavigationRailDestination(icon: Icon(Icons.apartment), label: Text('Entitats')),
              ],
            ),
          ],
        ),
      );
    }

    // Pantalla menuda (mòbil): barra a baix
    return Scaffold(
      body: pantalla,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pestanya,
        onDestinationSelected: (i) => setState(() => _pestanya = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map), label: 'Centres'),
          NavigationDestination(icon: Icon(Icons.support_agent), label: 'Serveis'),
          NavigationDestination(icon: Icon(Icons.apartment), label: 'Entitats'),
        ],
      ),
    );
  }
}
