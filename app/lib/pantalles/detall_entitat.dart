import 'package:flutter/material.dart';

import '../dades/api_ribera.dart';
import '../models/models.dart';
import '../widgets/comuns.dart';
import '../widgets/contactes.dart';
import '../navegacio.dart';
import 'detall_comu.dart';

/// Fitxa d'una entitat: dades, contactes, serveis que presta i centres que titula o gestiona.
class DetallEntitat extends StatelessWidget {
  final int id;

  const DetallEntitat({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return FitxaFutura<EntitatDetall>(
      titol: 'Entitat',
      carrega: () => apiRibera.entitat(id),
      construeix: (context, e) {
        final adreca = [
          if (e.adreca != null) e.adreca!,
          if (e.municipi != null) [if (e.codiPostal != null) e.codiPostal!, e.municipi!.nom].join(' '),
        ].join(', ');
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CapcaleraFitxa(
            icona: Icons.apartment_outlined,
            titol: e.nom,
            subtitol: [if (e.formaJuridica != null) e.formaJuridica!.nom, if (e.sector != null) 'Sector ${e.sector!.toLowerCase()}']
                .join(' · '),
          ),
          if (adreca.isNotEmpty) Seccio(titol: 'Adreça', icona: Icons.place_outlined, fills: [Dada('Seu', adreca)]),
          Seccio(titol: 'Contacte', icona: Icons.call_outlined, fills: [LlistaContactes(e.contactes)]),
          if (e.horaris.isNotEmpty) Seccio(titol: 'Horari', icona: Icons.schedule, fills: [LlistaHoraris(e.horaris)]),
          Seccio(titol: 'Serveis que presta', icona: Icons.volunteer_activism_outlined, fills: [
            if (e.serveisPrestats.isEmpty) const Nota('No consta cap servei prestat per aquesta entitat.'),
            for (final s in e.serveisPrestats)
              _Enllac(s.nom, Icons.volunteer_activism_outlined, () => obriServei(context, s.id)),
          ]),
          if (e.centresTitulats.isNotEmpty)
            Seccio(titol: 'Centres dels quals és titular', icona: Icons.home_work_outlined, fills: [
              for (final c in e.centresTitulats) _Enllac(c.nom, Icons.home_work_outlined, () => obriCentre(context, c.id), c.adrecaCompleta),
            ]),
          if (e.centresGestionats.isNotEmpty)
            Seccio(titol: 'Centres que gestiona', icona: Icons.home_work_outlined, fills: [
              for (final c in e.centresGestionats) _Enllac(c.nom, Icons.home_work_outlined, () => obriCentre(context, c.id), c.adrecaCompleta),
            ]),
          if (e.font != null) Seccio(titol: 'Procedència', icona: Icons.source_outlined, fills: [TextFont(e.font)]),
        ]);
      },
    );
  }
}

class _Enllac extends StatelessWidget {
  final String titol;
  final String? subtitol;
  final IconData icona;
  final VoidCallback onTap;

  const _Enllac(this.titol, this.icona, this.onTap, [this.subtitol]);

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(icona),
          title: Text(titol),
          subtitle: subtitol == null ? null : Text(subtitol!),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}
