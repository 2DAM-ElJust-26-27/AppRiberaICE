import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../estat/directori_estat.dart';
import '../models/models.dart';
import '../widgets/comuns.dart';
import '../widgets/contactes.dart';
import '../widgets/targetes.dart';

/// Mapa dels centres que tenen un punt conegut.
/// Els centres sense coordenades no es dibuixen (mai es posen a (0,0)).
class VistaMapa extends StatefulWidget {
  const VistaMapa({super.key});

  /// Centre aproximat de la Ribera Alta i la Ribera Baixa.
  static const centreRibera = LatLng(39.15, -0.40);

  @override
  State<VistaMapa> createState() => _VistaMapaState();
}

class _VistaMapaState extends State<VistaMapa> {
  final _mapa = MapController();
  CentreResum? _seleccionat;

  @override
  Widget build(BuildContext context) {
    final e = EstatDirectori.of(context);
    if (e.estatResultats == EstatCarrega.error) return MissatgeEstat.error(e.error ?? '', e.carrega);

    final t = Theme.of(context);
    final punts = e.punts.where((c) => c.tePunt).toList();
    final senseUbicacio = e.centres.length - punts.length;

    return Stack(children: [
      FlutterMap(
        mapController: _mapa,
        options: MapOptions(
          initialCenter: VistaMapa.centreRibera,
          initialZoom: 10,
          minZoom: 7,
          maxZoom: 18,
          onTap: (_, __) => setState(() => _seleccionat = null),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'cat.ribera.connectant_ribera',
          ),
          MarkerLayer(markers: [
            for (final c in punts)
              Marker(
                point: LatLng(c.latitud!, c.longitud!),
                width: 44,
                height: 44,
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () => setState(() => _seleccionat = c),
                  child: Tooltip(
                    message: c.nom,
                    child: Icon(
                      Icons.location_on,
                      size: 44,
                      color: c == _seleccionat ? t.colorScheme.tertiary : t.colorScheme.primary,
                      shadows: const [Shadow(blurRadius: 4, color: Colors.black26)],
                    ),
                  ),
                ),
              ),
          ]),
          RichAttributionWidget(
            alignment: AttributionAlignment.bottomLeft,
            attributions: [
              TextSourceAttribution(
                'Col·laboradors d\'OpenStreetMap',
                onTap: () => obriEnllac(context, Uri.parse('https://www.openstreetmap.org/copyright')),
              ),
            ],
          ),
        ],
      ),

      // Avís: quants centres no tenen ubicació coneguda
      Positioned(
        top: 8,
        left: 16,
        right: 16,
        child: Card(
          color: t.colorScheme.surface.withValues(alpha: 0.95),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Icon(Icons.info_outline, size: 18, color: t.colorScheme.outline),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${punts.length} ${punts.length == 1 ? 'centre' : 'centres'} amb ubicació'
                  '${senseUbicacio > 0 ? ' · $senseUbicacio sense coordenades conegudes (consulta la llista)' : ''}',
                  style: t.textTheme.bodySmall,
                ),
              ),
              if (e.estatResultats == EstatCarrega.carregant)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ]),
          ),
        ),
      ),

      // Fitxa breu del centre seleccionat
      if (_seleccionat != null)
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Card(
            elevation: 4,
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              title: Text(_seleccionat!.nom),
              subtitle: Text([
                if (_seleccionat!.tipusCentre != null) _seleccionat!.tipusCentre!.nom,
                if (_seleccionat!.adrecaCompleta != null) _seleccionat!.adrecaCompleta!,
                if (_seleccionat!.precisioPunt == 'punt_publicat') 'Punt publicat per la font (no verificat per GPS)',
              ].join('\n')),
              isThreeLine: true,
              trailing: FilledButton.tonal(
                onPressed: () => obriCentre(context, _seleccionat!.id),
                child: const Text('Fitxa'),
              ),
            ),
          ),
        ),
    ]);
  }
}
