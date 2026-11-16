import 'package:flutter/material.dart';

import '../dades/api_ribera.dart';
import '../estat/estat_app.dart';
import '../models/models.dart';

/// Full inferior amb els filtres de serveis de la pestanya Centres.
/// Les opcions de «Servei» es recalculen amb la resta de filtres.
Future<void> mostraFiltresCentres(BuildContext context) async {
  final estat = EstatApp.of(context);
  final resultat = await showModalBottomSheet<Filtres>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _FullFiltres(estat: estat, inicials: estat.centres.filtres),
  );
  if (resultat != null) estat.centres.aplica(resultat);
}

class _FullFiltres extends StatefulWidget {
  final EstatApp estat;
  final Filtres inicials;

  const _FullFiltres({required this.estat, required this.inicials});

  @override
  State<_FullFiltres> createState() => _FullFiltresState();
}

class _FullFiltresState extends State<_FullFiltres> {
  late Filtres f = widget.inicials;
  List<ServeiResum> _serveis = [];
  bool _carregantServeis = false;

  @override
  void initState() {
    super.initState();
    _serveis = widget.estat.centres.serveisDisponibles;
  }

  /// Canvia un filtre i torna a calcular quins serveis hi encaixen.
  Future<void> _canvia(Filtres nous) async {
    setState(() {
      f = nous;
      _carregantServeis = true;
    });
    try {
      final serveis = await widget.estat.directori.api.serveis(nous);
      if (!mounted) return;
      setState(() {
        _serveis = serveis;
        if (f.serveiId != null && !serveis.any((s) => s.id == f.serveiId)) {
          f = f.copyWith(serveiId: () => null); // el servei triat ja no encaixa
        }
      });
    } catch (_) {
      // Si falla, mantenim la llista anterior.
    } finally {
      if (mounted) setState(() => _carregantServeis = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final d = widget.estat.directori;
    final comarques = <String, List<Municipi>>{};
    for (final m in d.municipis) {
      comarques.putIfAbsent(m.comarca?.nom ?? 'Altres', () => []).add(m);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text('Busca serveis al mapa', style: t.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Es mostraran els centres on es presten els serveis que trieu.',
              style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),

          Text('Per a qui és el servei', style: t.textTheme.titleSmall),
          const SizedBox(height: 8),
          _Xips(
            opcions: d.catalegs.collectius,
            seleccionat: f.collectiu,
            onCanvi: (v) => _canvia(f.copyWith(collectiu: () => v)),
          ),
          const SizedBox(height: 24),

          DropdownMenu<int?>(
            key: ValueKey('municipi-${f.municipiId}'),
            initialSelection: f.municipiId,
            expandedInsets: EdgeInsets.zero,
            enableFilter: true,
            requestFocusOnTap: true,
            label: const Text('Municipi'),
            leadingIcon: const Icon(Icons.place_outlined),
            helperText: 'On és el centre',
            onSelected: (v) => _canvia(f.copyWith(municipiId: () => v)),
            dropdownMenuEntries: [
              const DropdownMenuEntry<int?>(value: null, label: 'Tots els municipis'),
              for (final entrada in comarques.entries)
                for (final m in entrada.value)
                  DropdownMenuEntry<int?>(value: m.id, label: m.nom, trailingIcon: Text(entrada.key, style: t.textTheme.labelSmall)),
            ],
          ),
          const SizedBox(height: 24),

          Text('Tipus de centre', style: t.textTheme.titleSmall),
          const SizedBox(height: 8),
          _Xips(
            opcions: d.catalegs.tipusCentre,
            seleccionat: f.tipusCentre,
            onCanvi: (v) => _canvia(f.copyWith(tipusCentre: () => v)),
          ),
          const SizedBox(height: 24),

          Row(children: [
            Text('Servei concret', style: t.textTheme.titleSmall),
            const SizedBox(width: 8),
            if (_carregantServeis) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
          const SizedBox(height: 8),
          DropdownMenu<int?>(
            key: ValueKey('servei-${f.serveiId}-${_serveis.length}'),
            initialSelection: f.serveiId,
            expandedInsets: EdgeInsets.zero,
            enableFilter: true,
            requestFocusOnTap: true,
            label: Text('${_serveis.length} serveis disponibles'),
            leadingIcon: const Icon(Icons.volunteer_activism_outlined),
            onSelected: (v) => setState(() => f = f.copyWith(serveiId: () => v)),
            dropdownMenuEntries: [
              const DropdownMenuEntry<int?>(value: null, label: 'Qualsevol servei'),
              for (final s in _serveis) DropdownMenuEntry<int?>(value: s.id, label: s.nom),
            ],
          ),
          const SizedBox(height: 28),

          Row(children: [
            TextButton(onPressed: () => _canvia(const Filtres()), child: const Text('Neteja')),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(f),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Mostra al mapa'),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Xips extends StatelessWidget {
  final List<Ref> opcions;
  final String? seleccionat;
  final ValueChanged<String?> onCanvi;

  const _Xips({required this.opcions, required this.seleccionat, required this.onCanvi});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final o in opcions)
        ChoiceChip(
          label: Text(o.nom),
          selected: o.codi == seleccionat,
          onSelected: (s) => onCanvi(s ? o.codi : null),
        ),
    ]);
  }
}
