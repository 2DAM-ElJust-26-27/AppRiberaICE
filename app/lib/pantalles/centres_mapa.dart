import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../estat/estat_app.dart';
import '../models/models.dart';
import '../widgets/comuns.dart';
import '../widgets/contactes.dart';
import '../widgets/filtres_centres.dart';
import '../widgets/targetes.dart';

/// Pestanya Centres: mapa amb filtres de serveis i llista dels centres on es presten.
/// Els centres sense coordenades no es dibuixen (mai a (0,0)); apareixen a la llista.
class PantallaCentres extends StatefulWidget {
  const PantallaCentres({super.key});

  /// Centre aproximat de la Ribera Alta i la Ribera Baixa.
  static const centreRibera = LatLng(39.15, -0.40);

  @override
  State<PantallaCentres> createState() => _PantallaCentresState();
}

class _PantallaCentresState extends State<PantallaCentres> {
  final _mapa = MapController();
  bool _mapaPreparat = false;
  CentreResum? _seleccionat;
  CentresEstat? _estat;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final e = EstatApp.of(context).centres;
    if (_estat != e) {
      _estat?.removeListener(_enquadra);
      _estat = e..addListener(_enquadra);
    }
  }

  @override
  void dispose() {
    _estat?.removeListener(_enquadra);
    super.dispose();
  }

  /// Ajusta la càmera als punts dels resultats quan arriben.
  void _enquadra() {
    final e = _estat!;
    if (!_mapaPreparat || e.estat != EstatCarrega.llest) return;
    if (_seleccionat != null && !e.centres.contains(_seleccionat)) _seleccionat = null;
    final punts = e.ambPunt.map((c) => LatLng(c.latitud!, c.longitud!)).toList();
    try {
      if (punts.isEmpty) {
        _mapa.move(PantallaCentres.centreRibera, 10);
      } else if (punts.length == 1) {
        _mapa.move(punts.first, 14);
      } else {
        _mapa.fitCamera(CameraFit.coordinates(coordinates: punts, padding: const EdgeInsets.all(64), maxZoom: 15));
      }
    } catch (_) {}
  }

  void _selecciona(CentreResum c) {
    if (!c.tePunt) {
      obriCentre(context, c.id);
      return;
    }
    setState(() => _seleccionat = c);
    _mapa.move(LatLng(c.latitud!, c.longitud!), 15);
  }

  @override
  Widget build(BuildContext context) {
    final e = EstatApp.of(context).centres;
    final ample = MediaQuery.sizeOf(context).width >= 840;

    return ListenableBuilder(
      listenable: e,
      builder: (context, _) {
        final mapa = _Mapa(
          controlador: _mapa,
          punts: e.ambPunt,
          seleccionat: _seleccionat,
          onPreparat: () {
            _mapaPreparat = true;
            _enquadra();
          },
          onTriaPunt: (c) => setState(() => _seleccionat = c),
          onTocaMapa: () => setState(() => _seleccionat = null),
        );
        final llista = _LlistaCentres(estat: e, seleccionat: _seleccionat, onTria: _selecciona);

        return Column(children: [
          const _BarraFiltres(), // escolta ella mateixa centres i catàlegs
          if (e.estat == EstatCarrega.carregant) const LinearProgressIndicator(minHeight: 2) else const SizedBox(height: 2),
          Expanded(
            child: e.estat == EstatCarrega.error
                ? MissatgeEstat.error(e.error ?? '', e.carrega)
                : ample
                    ? Row(children: [
                        Expanded(child: mapa),
                        const VerticalDivider(width: 1),
                        SizedBox(width: 400, child: llista),
                      ])
                    : Stack(children: [
                        Positioned.fill(child: mapa),
                        DraggableScrollableSheet(
                          initialChildSize: 0.32,
                          minChildSize: 0.12,
                          maxChildSize: 0.9,
                          snap: true,
                          builder: (context, scroll) => Material(
                            elevation: 8,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                            clipBehavior: Clip.antiAlias,
                            child: _LlistaCentres(estat: e, seleccionat: _seleccionat, onTria: _selecciona, scroll: scroll, ambNansa: true),
                          ),
                        ),
                      ]),
          ),
        ]);
      },
    );
  }
}

// ------------------------------------------------------------------ barra de filtres

class _BarraFiltres extends StatelessWidget {
  const _BarraFiltres();

  @override
  Widget build(BuildContext context) {
    final app = EstatApp.of(context);
    final e = app.centres;
    final d = app.directori;
    return ListenableBuilder(
      listenable: Listenable.merge([e, d]),
      builder: (context, _) => _construeix(context, e, d),
    );
  }

  Widget _construeix(BuildContext context, CentresEstat e, DirectoriEstat d) {
    final f = e.filtres;
    final t = Theme.of(context);

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Badge(
            isLabelVisible: f.actius,
            label: Text('${f.nombreActius}'),
            child: FilledButton.tonalIcon(
              onPressed: d.estatCatalegs == EstatCarrega.llest ? () => mostraFiltresCentres(context) : null,
              icon: const Icon(Icons.tune),
              label: const Text('Filtra per servei'),
            ),
          ),
          const SizedBox(width: 8),
          if (!f.actius)
            Center(
              child: Text('Mostrant tots els centres',
                  style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            ),
          if (f.serveiId != null)
            _Xip(Icons.volunteer_activism_outlined, e.serveiSeleccionat?.nom ?? 'Servei', () => e.aplica(f.copyWith(serveiId: () => null))),
          if (f.collectiu != null)
            _Xip(Icons.groups_outlined, d.nomCataleg(d.catalegs.collectius, f.collectiu) ?? '',
                () => e.aplica(f.copyWith(collectiu: () => null))),
          if (f.municipiId != null)
            _Xip(Icons.place_outlined, d.nomMunicipi(f.municipiId) ?? '', () => e.aplica(f.copyWith(municipiId: () => null))),
          if (f.tipusCentre != null)
            _Xip(Icons.home_work_outlined, d.nomCataleg(d.catalegs.tipusCentre, f.tipusCentre) ?? '',
                () => e.aplica(f.copyWith(tipusCentre: () => null))),
          if (f.actius) TextButton(onPressed: e.neteja, child: const Text('Neteja-ho tot')),
        ],
      ),
    );
  }
}

class _Xip extends StatelessWidget {
  final IconData icona;
  final String text;
  final VoidCallback lleva;

  const _Xip(this.icona, this.text, this.lleva);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InputChip(
          avatar: Icon(icona, size: 18),
          label: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220), child: Text(text, overflow: TextOverflow.ellipsis)),
          onDeleted: lleva,
        ),
      );
}

// ------------------------------------------------------------------ mapa

class _Mapa extends StatelessWidget {
  final MapController controlador;
  final List<CentreResum> punts;
  final CentreResum? seleccionat;
  final VoidCallback onPreparat;
  final ValueChanged<CentreResum> onTriaPunt;
  final VoidCallback onTocaMapa;

  const _Mapa({
    required this.controlador,
    required this.punts,
    required this.seleccionat,
    required this.onPreparat,
    required this.onTriaPunt,
    required this.onTocaMapa,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Stack(children: [
      FlutterMap(
        mapController: controlador,
        options: MapOptions(
          initialCenter: PantallaCentres.centreRibera,
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
          right: 16,
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
              trailing: FilledButton.tonal(onPressed: () => obriCentre(context, seleccionat!.id), child: const Text('Fitxa')),
            ),
          ),
        ),
    ]);
  }
}

// ------------------------------------------------------------------ llista

class _LlistaCentres extends StatelessWidget {
  final CentresEstat estat;
  final CentreResum? seleccionat;
  final ValueChanged<CentreResum> onTria;
  final ScrollController? scroll;
  final bool ambNansa;

  const _LlistaCentres({required this.estat, required this.seleccionat, required this.onTria, this.scroll, this.ambNansa = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final centres = estat.centres;
    final ambPunt = centres.where((c) => c.tePunt).length;
    final carregant = estat.estat != EstatCarrega.llest && centres.isEmpty;

    return CustomScrollView(controller: scroll, slivers: [
      SliverToBoxAdapter(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (ambNansa)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: t.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              carregant ? 'Carregant centres…' : '${centres.length} ${centres.length == 1 ? 'centre' : 'centres'}',
              style: t.textTheme.titleMedium,
            ),
          ),
          if (!carregant && centres.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Nota(ambPunt == centres.length
                  ? 'Tots apareixen al mapa.'
                  : '$ambPunt al mapa · ${centres.length - ambPunt} sense coordenades conegudes (toca per vore la fitxa).'),
            ),
        ]),
      ),
      if (carregant)
        const SliverToBoxAdapter(child: Carregant())
      else if (centres.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const Nota('Cap centre coincideix amb aquests filtres. Pot ser que el servei no tinga cap centre associat '
                  '(la ubicació pot ser desconeguda) o que no hi haja dades.'),
              if (estat.filtres.actius) TextButton(onPressed: estat.neteja, child: const Text('Neteja els filtres')),
            ]),
          ),
        )
      else
        SliverList.builder(
          itemCount: centres.length,
          itemBuilder: (context, i) {
            final c = centres[i];
            return ListTile(
              selected: c == seleccionat,
              leading: Icon(c.tePunt ? Icons.location_on : Icons.location_off_outlined,
                  color: c.tePunt ? t.colorScheme.primary : t.colorScheme.outline),
              title: Text(c.nom),
              subtitle: Text([if (c.tipusCentre != null) c.tipusCentre!.nom, if (c.municipi != null) c.municipi!.nom].join(' · ')),
              trailing: IconButton(
                tooltip: 'Obri la fitxa',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => obriCentre(context, c.id),
              ),
              onTap: () => onTria(c),
            );
          },
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ]);
  }
}
