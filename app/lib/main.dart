import 'package:flutter/material.dart';

import 'dades/api_ribera.dart';
import 'estat/assistent_estat.dart';
import 'estat/estat_app.dart';
import 'pantalles/inici.dart';
import 'tema.dart';

void main() {
  final api = ApiRibera();
  runApp(ConnectantRibera(
    directori: DirectoriEstat(api)..inicialitza(),
    centres: CentresEstat(api)..carrega(),
    assistent: AssistentEstat(api)..comenca(),
  ));
}

class ConnectantRibera extends StatelessWidget {
  final DirectoriEstat directori;
  final CentresEstat centres;
  final AssistentEstat assistent;

  ConnectantRibera({super.key, required this.directori, required this.centres, required this.assistent});

  final _pestanya = ValueNotifier(Pestanya.serveis);

  @override
  Widget build(BuildContext context) {
    return EstatApp(
      directori: directori,
      centres: centres,
      assistent: assistent,
      pestanya: _pestanya,
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
