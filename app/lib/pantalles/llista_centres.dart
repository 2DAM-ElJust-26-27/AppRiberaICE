import 'package:flutter/material.dart';

import '../estat/directori_estat.dart';
import '../widgets/targetes.dart';
import '../widgets/vista_resultats.dart';

/// Llista de centres amb els filtres actuals.
class LlistaCentres extends StatelessWidget {
  const LlistaCentres({super.key});

  @override
  Widget build(BuildContext context) {
    final e = EstatDirectori.of(context);
    return VistaResultats(
      estat: e,
      buit: e.centres.isEmpty,
      textBuit: 'Cap centre coincideix amb la cerca i els filtres.',
      itemCount: e.centres.length,
      itemBuilder: (i) => TargetaCentre(e.centres[i]),
    );
  }
}
