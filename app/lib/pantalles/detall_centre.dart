import 'package:flutter/material.dart';

import '../models/models.dart';
import '../widgets/comuns.dart';
import '../widgets/contactes.dart';
import 'detall_comu.dart';
import 'detall_entitat.dart';
import 'detall_servei.dart';

/// Fitxa d'un centre: ubicació, titular i gestor, contactes i serveis que s'hi presten.
class DetallCentre extends StatelessWidget {
  final int id;

  const DetallCentre({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return FitxaFutura<CentreDetall>(
      titol: 'Centre',
      carrega: () => context.directori.api.centre(id),
      construeix: (context, d) {
        final c = d.resum;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CapcaleraFitxa(icona: Icons.home_work_outlined, titol: c.nom, subtitol: c.tipusCentre?.nom),
          Seccio(titol: 'Ubicació', icona: Icons.place_outlined, fills: [
            if (c.adrecaCompleta != null) Dada('Adreça', c.adrecaCompleta!) else const Nota('Adreça no coneguda.'),
            if (c.municipi != null) Dada('Municipi', c.municipi!.nom),
            if (c.tePunt) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.map_outlined),
                label: const Text('Obri al mapa'),
                onPressed: () => obriEnllac(
                  context,
                  Uri.parse('https://www.openstreetmap.org/?mlat=${c.latitud}&mlon=${c.longitud}#map=17/${c.latitud}/${c.longitud}'),
                ),
              ),
              if (c.precisioPunt == 'punt_publicat')
                const Nota('Punt publicat per la font oficial, no és una mesura GPS verificada.'),
              TextFont(d.fontPunt, prefix: 'Font del punt'),
            ] else
              const Nota('Sense coordenades conegudes: no apareix al mapa.'),
            const Nota('Les adreces requereixen revisió futura.'),
          ]),
          Seccio(titol: 'Titularitat i gestió', icona: Icons.apartment_outlined, fills: [
            _Entitat('Titular', d.titular),
            _Entitat('Gestor', d.gestor),
          ]),
          Seccio(titol: 'Serveis que s\'hi presten', icona: Icons.volunteer_activism_outlined, fills: [
            if (d.serveis.isEmpty) const Nota('No consta cap servei relacionat amb aquest centre.'),
            for (final s in d.serveis)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(s.nom),
                  subtitle: s.entitats.isEmpty ? null : Text(s.entitats.map((e) => e.nom).join(' · ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetallServei(id: s.id))),
                ),
              ),
          ]),
          Seccio(titol: 'Contacte', icona: Icons.call_outlined, fills: [LlistaContactes(d.contactes)]),
          Seccio(titol: 'Horari', icona: Icons.schedule, fills: [LlistaHoraris(d.horaris)]),
          if (d.font != null) Seccio(titol: 'Procedència', icona: Icons.source_outlined, fills: [TextFont(d.font)]),
        ]);
      },
    );
  }
}

class _Entitat extends StatelessWidget {
  final String rol;
  final Ref? entitat;

  const _Entitat(this.rol, this.entitat);

  @override
  Widget build(BuildContext context) {
    final e = entitat;
    if (e == null) return Dada(rol, 'No acreditat');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.apartment),
      title: Text(e.nom),
      subtitle: Text(rol),
      trailing: const Icon(Icons.chevron_right),
      onTap: e.id == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetallEntitat(id: e.id!))),
    );
  }
}
