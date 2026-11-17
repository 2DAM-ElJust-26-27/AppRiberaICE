import 'package:flutter/material.dart';

import 'pantalles/inici.dart';
import 'tema.dart';

void main() {
  runApp(const ConnectantRibera());
}

class ConnectantRibera extends StatelessWidget {
  const ConnectantRibera({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Connectant la Ribera',
      debugShowCheckedModeBanner: false,
      theme: Tema.clar(),
      darkTheme: Tema.fosc(),
      home: const PantallaInici(),
    );
  }
}
