import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../dades/api_ribera.dart';
import '../models/models.dart';
import '../widgets/comuns.dart';
import '../navegacio.dart';
import '../widgets/barra_filtres.dart';
import '../widgets/filtres_centres.dart';
import '../widgets/llista_centres.dart';
import '../widgets/mapa_centres.dart';

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

  /// En pantalla gran, la llista és un panell flotant a la dreta del mapa.
  bool _panellObert = false;

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
      // Les dues peticions van alhora (no una darrere l'altra).
      final (centres, serveis) = await (apiRibera.centres(_filtres), apiRibera.serveis(_filtres)).wait;
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
        _mapa.move(MapaCentres.centreRibera, 10);
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
    final ample = MediaQuery.sizeOf(context).width >= 840;
    final mapa = MapaCentres(
      controlador: _mapa,
      punts: _ambPunt,
      seleccionat: _seleccionat,
      onPreparat: () {
        _mapaPreparat = true;
        _enquadra();
      },
      onTriaPunt: (c) => setState(() => _seleccionat = c),
      onTocaMapa: () => setState(() => _seleccionat = null),
      margeDret: ample && _panellObert ? 404 : 16,
    );

    final Widget cos = _estat == EstatCarrega.error
        ? MissatgeEstat.error(_error ?? '', _carrega)
        : Stack(children: [
            Positioned.fill(child: mapa),
            if (ample && _panellObert)
              Positioned(top: 12, right: 12, bottom: 36, width: 380, child: Card(elevation: 6, clipBehavior: Clip.antiAlias, child: _llista()))
            else
              Positioned(
                right: 16,
                bottom: 48,
                child: FloatingActionButton.extended(
                  heroTag: 'llista-centres',
                  onPressed: ample ? () => setState(() => _panellObert = true) : _mostraLlista,
                  icon: const Icon(Icons.list),
                  label: Text('Llista (${_centres.length})'),
                ),
              ),
          ]);

    return Column(children: [
      BarraFiltres(
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
      // Marge als costats i per baix perquè el mapa no quede tallat a la vora de la finestra.
      Expanded(child: Marc(child: cos)),
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

  /// Llista de centres. [enFull]: dins del full inferior, que cal tancar en triar.
  Widget _llista({bool enFull = false, ScrollController? scroll}) {
    void tanca() {
      if (enFull) Navigator.of(context).pop();
    }

    return LlistaCentres(
      centres: _centres,
      carregant: _estat == EstatCarrega.carregant,
      seleccionat: _seleccionat,
      filtresActius: _filtres.actius,
      scroll: scroll,
      onTanca: enFull ? null : () => setState(() => _panellObert = false),
      onTria: (c) {
        tanca(); // mostra el centre al mapa
        _selecciona(c);
      },
      onFitxa: (c) {
        tanca();
        obriCentre(context, c.id);
      },
      onNeteja: () {
        tanca();
        _neteja();
      },
    );
  }

  /// Mòbil: la llista s'obri en un full inferior que es pot arrossegar i tancar.
  void _mostraLlista() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (_, scroll) => _llista(enFull: true, scroll: scroll),
      ),
    );
  }
}
