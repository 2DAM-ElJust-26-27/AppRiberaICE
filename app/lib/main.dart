import 'package:flutter/material.dart';

import 'dades/api_ribera.dart';
import 'estat/directori_estat.dart';
import 'pantalles/inici.dart';
import 'tema.dart';

void main() {
  final estat = DirectoriEstat(ApiRibera())..inicialitza();
  runApp(ConnectantRibera(estat: estat));
}

class ConnectantRibera extends StatelessWidget {
  final DirectoriEstat estat;

  const ConnectantRibera({super.key, required this.estat});

  @override
  Widget build(BuildContext context) {
    return EstatDirectori(
      estat: estat,
      child: MaterialApp(
        title: 'Connectant la Ribera',
        debugShowCheckedModeBanner: false,
        theme: Tema.clar(),
        darkTheme: Tema.fosc(),
        home: const PantallaInici(),
      ),
    );
  }
}
