import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/models.dart';
import '../navegacio.dart';
import 'contactes.dart';

/// Mapa amb els centres que tenen punt i la targeta del centre seleccionat.
class MapaCentres extends StatelessWidget {
  /// Centre aproximat de la Ribera Alta i la Ribera Baixa.
  static const centreRibera = LatLng(39.15, -0.40);

  final MapController controlador;
  final List<CentreResum> punts;
  final CentreResum? seleccionat;
  final VoidCallback onPreparat;
  final ValueChanged<CentreResum> onTriaPunt;
  final VoidCallback onTocaMapa;
  final double margeDret;

  const MapaCentres({
    super.key,
    required this.controlador,
    required this.punts,
    required this.seleccionat,
    required this.onPreparat,
    required this.onTriaPunt,
    required this.onTocaMapa,
    this.margeDret = 16,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Stack(children: [
      FlutterMap(
        mapController: controlador,
        options: MapOptions(
          initialCenter: MapaCentres.centreRibera,
          initialZoom: 10,
          minZoom: 7,
          maxZoom: 18,
          onMapReady: onPreparat,
          onTap: (_, __) => onTocaMapa(),
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
                  onTap: () => onTriaPunt(c),
                  child: Tooltip(
                    message: c.nom,
                    child: Icon(
                      Icons.location_on,
                      size: 44,
                      color: c == seleccionat ? t.colorScheme.tertiary : t.colorScheme.primary,
                      shadows: const [Shadow(blurRadius: 4, color: Colors.black26)],
                    ),
                  ),
                ),
              ),
          ]),
          RichAttributionWidget(
            alignment: AttributionAlignment.bottomRight,
            attributions: [
              TextSourceAttribution(
                'Col·laboradors d\'OpenStreetMap',
                onTap: () => obriEnllac(context, Uri.parse('https://www.openstreetmap.org/copyright')),
              ),
            ],
          ),
        ],
      ),
      if (seleccionat != null)
        Positioned(
          left: 16,
          right: margeDret,
          top: 12,
          child: Card(
            elevation: 4,
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              title: Text(seleccionat!.nom),
              subtitle: Text([
                if (seleccionat!.tipusCentre != null) seleccionat!.tipusCentre!.nom,
                if (seleccionat!.adrecaCompleta != null) seleccionat!.adrecaCompleta!,
                if (seleccionat!.textPrecisio != null) seleccionat!.textPrecisio!,
              ].join('\n')),
              isThreeLine: true,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                FilledButton.tonal(onPressed: () => obriCentre(context, seleccionat!.id), child: const Text('Fitxa')),
                IconButton(tooltip: 'Tanca', icon: const Icon(Icons.close), onPressed: onTocaMapa),
              ]),
            ),
          ),
        ),
    ]);
  }
}
