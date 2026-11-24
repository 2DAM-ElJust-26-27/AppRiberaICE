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
    return Scaffold(
      // IndexedStack manté les pestanyes vives: en tornar, no es tornen a carregar
      body: IndexedStack(
        index: _pestanya,
        children: const [PantallaCentres(), PantallaAssistent(), PantallaEntitats()],
      ),
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
