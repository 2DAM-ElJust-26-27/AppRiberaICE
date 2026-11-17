import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../dades/api_ribera.dart';
import '../models/models.dart';
import '../widgets/comuns.dart';
import '../widgets/contactes.dart';
import '../widgets/filtres_centres.dart';
import '../widgets/targetes.dart';

/// Pestanya Centres: mapa amb filtres de serveis i llista dels centres on es presten.
/// Els centres sense coordenades no es dibuixen (mai a (0,0)); apareixen a la llista.
///
/// Tot l'estat (filtres, resultats, centre seleccionat) es guarda en aquest
/// `State` i es canvia amb `setState`.
class PantallaCentres extends StatefulWidget {
  final List<Municipi> municipis;
  final Catalegs catalegs;
  final bool catalegsCarregats;

  /// Filtres que arriben des d'una altra pestanya (l'assistent). Quan canvien, s'apliquen.
  final Filtres? filtresExterns;

  const PantallaCentres({
    super.key,
    required this.municipis,
    required this.catalegs,
    required this.catalegsCarregats,
    this.filtresExterns,
  });

  /// Centre aproximat de la Ribera Alta i la Ribera Baixa.
  static const centreRibera = LatLng(39.15, -0.40);

  @override
  State<PantallaCentres> createState() => _PantallaCentresState();
}

class _PantallaCentresState extends State<PantallaCentres> {
  final _mapa = MapController();
  bool _mapaPreparat = false;
  CentreResum? _seleccionat;

  Filtres _filtres = const Filtres();
  List<CentreResum> _centres = [];
  List<ServeiResum> _serveis = []; // serveis que encaixen amb els filtres (per al selector de servei)
  EstatCarrega _estat = EstatCarrega.carregant;
  String? _error;
  int _peticio = 0; // per ignorar respostes velles si l'usuari canvia de filtre ràpid

  List<CentreResum> get _ambPunt => _centres.where((c) => c.tePunt).toList();

  @override
  void initState() {
    super.initState();
    if (widget.filtresExterns != null) _filtres = widget.filtresExterns!;
    _carrega();
  }

  @override
  void didUpdateWidget(PantallaCentres anterior) {
    super.didUpdateWidget(anterior);
    // L'assistent ens ha enviat filtres nous.
    if (widget.filtresExterns != null && widget.filtresExterns != anterior.filtresExterns) {
      _aplica(widget.filtresExterns!);
    }
  }

  Future<void> _carrega() async {
    final num = ++_peticio;
    setState(() {
      _estat = EstatCarrega.carregant;
      _error = null;
    });
    try {
      final centres = await apiRibera.centres(_filtres);
      final serveis = await apiRibera.serveis(_filtres);
      if (num != _peticio || !mounted) return;
      setState(() {
        _centres = centres;
        _serveis = serveis;
        _estat = EstatCarrega.llest;
        if (_seleccionat != null && !_centres.contains(_seleccionat)) _seleccionat = null;
      });
      _enquadra();
    } catch (e) {
      if (num != _peticio || !mounted) return;
      setState(() {
        _estat = EstatCarrega.error;
        _error = e.toString();
      });
    }
  }

  void _aplica(Filtres nous) {
    _filtres = nous;
    _carrega();
  }

  void _neteja() => _aplica(const Filtres());

  /// Ajusta la càmera als punts dels resultats.
  void _enquadra() {
    if (!_mapaPreparat || _estat != EstatCarrega.llest) return;
    final punts = _ambPunt.map((c) => LatLng(c.latitud!, c.longitud!)).toList();
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

  Future<void> _obriFiltres() async {
    final nous = await mostraFiltresCentres(
      context,
      filtres: _filtres,
      municipis: widget.municipis,
      catalegs: widget.catalegs,
      serveis: _serveis,
    );
    if (nous != null) _aplica(nous);
  }

  @override
  Widget build(BuildContext context) {
    final mapa = _Mapa(
      controlador: _mapa,
      punts: _ambPunt,
      seleccionat: _seleccionat,
      onPreparat: () {
        _mapaPreparat = true;
        _enquadra();
      },
      onTriaPunt: (c) => setState(() => _seleccionat = c),
      onTocaMapa: () => setState(() => _seleccionat = null),
    );

    final Widget cos = _estat == EstatCarrega.error
        ? MissatgeEstat.error(_error ?? '', _carrega)
        : Stack(children: [
            Positioned.fill(child: mapa),
            Positioned(
              right: 16,
              bottom: 48,
              child: FloatingActionButton.extended(
                heroTag: 'llista-centres',
                onPressed: _mostraLlista,
                icon: const Icon(Icons.list),
                label: Text('Llista (${_centres.length})'),
              ),
            ),
          ]);

    return Column(children: [
      _BarraFiltres(
        filtres: _filtres,
        actiu: widget.catalegsCarregats,
        nomServei: _nomServei(_filtres.serveiId),
        nomCollectiu: _nomCataleg(widget.catalegs.collectius, _filtres.collectiu),
        nomMunicipi: _nomMunicipi(_filtres.municipiId),
        nomTipus: _nomCataleg(widget.catalegs.tipusCentre, _filtres.tipusCentre),
        onObriFiltres: _obriFiltres,
        onCanvia: _aplica,
        onNeteja: _neteja,
      ),
      if (_estat == EstatCarrega.carregant) const LinearProgressIndicator(minHeight: 2) else const SizedBox(height: 2),
      Expanded(child: cos),
    ]);
  }

  String? _nomServei(int? id) {
    for (final s in _serveis) {
      if (s.id == id) return s.nom;
    }
    return id == null ? null : 'Servei';
  }

  String? _nomMunicipi(int? id) {
    for (final m in widget.municipis) {
      if (m.id == id) return m.nom;
    }
    return null;
  }

  String? _nomCataleg(List<Ref> llista, String? codi) {
    for (final r in llista) {
      if (r.codi == codi) return r.nom;
    }
    return codi;
  }

  /// Obri la llista de centres en un full inferior que es pot arrossegar i tancar.
  void _mostraLlista() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (fullContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (_, scroll) => CustomScrollView(controller: scroll, slivers: [
          _CapcaleraLlista(centres: _centres, carregant: _estat == EstatCarrega.carregant),
          ..._llistaSlivers(fullContext),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ]),
      ),
    );
  }

  List<Widget> _llistaSlivers(BuildContext context) {
    final t = Theme.of(context);
    final centres = _centres;
    if (_estat != EstatCarrega.llest && centres.isEmpty) {
      return const [SliverToBoxAdapter(child: Carregant())];
    }
    if (centres.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const Nota('Cap centre coincideix amb aquests filtres. Pot ser que el servei no tinga cap centre associat '
                  '(la ubicació pot ser desconeguda) o que no hi haja dades.'),
              if (_filtres.actius)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _neteja();
                  },
                  child: const Text('Neteja els filtres'),
                ),
            ]),
          ),
        ),
      ];
    }
    return [
      SliverList.builder(
        itemCount: centres.length,
        itemBuilder: (context, i) {
          final c = centres[i];
          return ListTile(
            selected: c == _seleccionat,
            leading: Icon(c.tePunt ? Icons.location_on : Icons.location_off_outlined,
                color: c.tePunt ? t.colorScheme.primary : t.colorScheme.outline),
            title: Text(c.nom),
            subtitle: Text([if (c.tipusCentre != null) c.tipusCentre!.nom, if (c.municipi != null) c.municipi!.nom].join(' · ')),
            trailing: IconButton(
              tooltip: 'Obri la fitxa',
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                Navigator.of(context).pop();
                obriCentre(this.context, c.id);
              },
            ),
            onTap: () {
              Navigator.of(context).pop(); // tanca la llista i mostra el centre al mapa
              _selecciona(c);
            },
          );
        },
      ),
    ];
  }
}

/// Capçalera de la llista de centres: recompte i quants surten al mapa.
class _CapcaleraLlista extends StatelessWidget {
  final List<CentreResum> centres;
  final bool carregant;

  const _CapcaleraLlista({required this.centres, required this.carregant});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final ambPunt = centres.where((c) => c.tePunt).length;
    final buit = carregant && centres.isEmpty;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(buit ? 'Carregant centres…' : '${centres.length} ${centres.length == 1 ? 'centre' : 'centres'}',
              style: t.textTheme.titleMedium),
          if (!buit && centres.isNotEmpty)
            Text(
              ambPunt == centres.length ? 'Tots apareixen al mapa' : '$ambPunt al mapa · ${centres.length - ambPunt} sense coordenades (toca per vore la fitxa)',
              style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ barra de filtres

/// Barra superior: botó de filtres i xips dels filtres actius (es poden llevar d'un en un).
class _BarraFiltres extends StatelessWidget {
  final Filtres filtres;
  final bool actiu;
  final String? nomServei, nomCollectiu, nomMunicipi, nomTipus;
  final VoidCallback onObriFiltres;
  final ValueChanged<Filtres> onCanvia;
  final VoidCallback onNeteja;

  const _BarraFiltres({
    required this.filtres,
    required this.actiu,
    required this.nomServei,
    required this.nomCollectiu,
    required this.nomMunicipi,
    required this.nomTipus,
    required this.onObriFiltres,
    required this.onCanvia,
    required this.onNeteja,
  });

  @override
  Widget build(BuildContext context) {
    final f = filtres;
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
              onPressed: actiu ? onObriFiltres : null,
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
            _Xip(Icons.volunteer_activism_outlined, nomServei ?? 'Servei', () => onCanvia(f.copyWith(serveiId: () => null))),
          if (f.collectiu != null)
            _Xip(Icons.groups_outlined, nomCollectiu ?? '', () => onCanvia(f.copyWith(collectiu: () => null))),
          if (f.municipiId != null)
            _Xip(Icons.place_outlined, nomMunicipi ?? '', () => onCanvia(f.copyWith(municipiId: () => null))),
          if (f.tipusCentre != null)
            _Xip(Icons.home_work_outlined, nomTipus ?? '', () => onCanvia(f.copyWith(tipusCentre: () => null))),
          if (f.actius) TextButton(onPressed: onNeteja, child: const Text('Neteja-ho tot')),
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
