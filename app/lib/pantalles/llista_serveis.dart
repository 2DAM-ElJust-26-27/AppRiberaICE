import 'package:flutter/material.dart';

import '../estat/directori_estat.dart';
import '../widgets/vista_resultats.dart';
import '../widgets/targetes.dart';

/// Llista de serveis amb els filtres actuals.
class LlistaServeis extends StatelessWidget {
  const LlistaServeis({super.key});

  @override
  Widget build(BuildContext context) {
    final e = EstatDirectori.of(context);
    return VistaResultats(
      estat: e,
      buit: e.serveis.isEmpty,
      textBuit: 'Cap servei coincideix amb la cerca i els filtres. Un resultat buit només descriu aquestes dades, '
          'no l\'absència real de recursos a la comarca.',
      itemCount: e.serveis.length,
      itemBuilder: (i) => TargetaServei(e.serveis[i]),
    );
  }
}
