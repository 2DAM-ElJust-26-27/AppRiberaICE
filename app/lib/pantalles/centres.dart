import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api.dart';
import '../models.dart';
import '../widgets.dart';
import 'fitxa_centre.dart';

/// Pestanya Centres: mapa (o llista) amb un filtre per servei.
class PantallaCentres extends StatefulWidget {
  const PantallaCentres({super.key});

  @override
  State<PantallaCentres> createState() => _PantallaCentresState();
}

class _PantallaCentresState extends State<PantallaCentres> {
  Future<List<Centre>> _centres = getCentres();
  final Future<List<Servei>> _serveis = getServeis();
  int? _serveiTriat;          // null = tots els serveis
  bool _veureLlista = false;  // false = mapa, true = llista

  /// Quan l'usuari tria un servei, tornem a demanar els centres a l'API.
  void _triaServei(int? serveiId) {
    setState(() {
      _serveiTriat = serveiId;
      _centres = getCentres(serveiId: serveiId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Centres'),
        actions: [
          IconButton(
            tooltip: _veureLlista ? 'Veure el mapa' : 'Veure la llista',
            icon: Icon(_veureLlista ? Icons.map : Icons.list),
            onPressed: () => setState(() => _veureLlista = !_veureLlista),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ambDades(_serveis, _filtre),
          ),
          Expanded(
            child: ambDades(_centres, (centres) => _veureLlista ? _llista(centres) : _mapa(centres)),
          ),
        ],
      ),
    );
  }

  /// Desplegable amb els serveis que es fan en algun centre.
  Widget _filtre(List<Servei> serveis) {
    final ambCentres = serveis.where((s) => s.municipis.isNotEmpty).toList();
    return DropdownButton<int?>(
      isExpanded: true,
      value: _serveiTriat,
      items: [
        const DropdownMenuItem(value: null, child: Text('Tots els serveis')),
        for (final s in ambCentres)
          DropdownMenuItem(value: s.id, child: Text(s.nom, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: _triaServei,
    );
  }

  Widget _mapa(List<Centre> centres) {
    final ambUbicacio = centres.where((c) => c.teUbicacio).toList();
    return FlutterMap(
      options: const MapOptions(initialCenter: LatLng(39.15, -0.35), initialZoom: 10),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'cat.ribera.connectant_ribera',
        ),
        MarkerLayer(
          markers: [
            for (final c in ambUbicacio)
              Marker(
                point: LatLng(c.latitud!, c.longitud!),
                width: 40,
                height: 40,
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () => _mostraCentre(c),
                  child: Icon(Icons.location_on, size: 40, color: Theme.of(context).colorScheme.primary),
                ),
              ),
          ],
        ),
        const SimpleAttributionWidget(source: Text('OpenStreetMap')),
      ],
    );
  }

  Widget _llista(List<Centre> centres) {
    return ListView(
      children: [
        for (final c in centres)
          ListTile(
            leading: Icon(c.teUbicacio ? Icons.place : Icons.location_off),
            title: Text(c.nom),
            subtitle: Text(c.municipi ?? ''),
            onTap: () => obri(context, FitxaCentre(c.id)),
          ),
      ],
    );
  }

  /// En tocar un punt del mapa, ix una targeta des de baix.
  void _mostraCentre(Centre c) {
    showModalBottomSheet(
      context: context,
      builder: (contextFulla) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.nom, style: Theme.of(contextFulla).textTheme.titleLarge),
            if (c.tipus != null) Text(c.tipus!),
            Text('${c.adreca ?? ''}, ${c.municipi ?? ''}'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.pop(contextFulla);       // tanca la targeta
                obri(context, FitxaCentre(c.id));  // i obri la fitxa
              },
              child: const Text('Veure la fitxa'),
            ),
          ],
        ),
      ),
    );
  }
}
