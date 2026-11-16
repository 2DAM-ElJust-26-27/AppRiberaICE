import 'package:flutter/material.dart';

import '../dades/api_ribera.dart';
import '../estat/directori_estat.dart';
import '../models/models.dart';

/// Obri el full inferior de filtres i aplica els que trie l'usuari.
Future<void> mostraFiltres(BuildContext context) async {
  final estat = EstatDirectori.llig(context);
  final resultat = await showModalBottomSheet<Filtres>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _FullFiltres(estat: estat, inicials: estat.filtres),
  );
  if (resultat != null) estat.aplica(resultat);
}

class _FullFiltres extends StatefulWidget {
  final DirectoriEstat estat;
  final Filtres inicials;

  const _FullFiltres({required this.estat, required this.inicials});

  @override
  State<_FullFiltres> createState() => _FullFiltresState();
}

class _FullFiltresState extends State<_FullFiltres> {
  late Filtres f = widget.inicials;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final e = widget.estat;
    final comarques = <String, List<Municipi>>{};
    for (final m in e.municipis) {
      comarques.putIfAbsent(m.comarca?.nom ?? 'Altres', () => []).add(m);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text('Filtres', style: t.textTheme.titleLarge),
          const SizedBox(height: 20),

          // ---- Municipi (on es presta el servei / on és el centre)
          DropdownMenu<int?>(
            initialSelection: f.municipiId,
            expandedInsets: EdgeInsets.zero,
            enableFilter: true,
            requestFocusOnTap: true,
            label: const Text('Municipi'),
            leadingIcon: const Icon(Icons.place_outlined),
            helperText: 'Serveis prestats en un centre d\'aquest municipi',
            onSelected: (v) => setState(() => f = f.copyWith(municipiId: () => v)),
            dropdownMenuEntries: [
              const DropdownMenuEntry<int?>(value: null, label: 'Tots els municipis'),
              for (final entrada in comarques.entries)
                for (final m in entrada.value)
                  DropdownMenuEntry<int?>(value: m.id, label: m.nom, trailingIcon: Text(entrada.key, style: t.textTheme.labelSmall)),
            ],
          ),
          const SizedBox(height: 24),

          // ---- Col·lectiu
          Text('Col·lectiu', style: t.textTheme.titleSmall),
          const SizedBox(height: 8),
          _Xips(
            opcions: e.catalegs.collectius,
            seleccionat: f.collectiu,
            onCanvi: (v) => setState(() => f = f.copyWith(collectiu: () => v)),
          ),
          const SizedBox(height: 24),

          // ---- Tipus de centre
          Text('Tipus de centre', style: t.textTheme.titleSmall),
          const SizedBox(height: 8),
          _Xips(
            opcions: e.catalegs.tipusCentre,
            seleccionat: f.tipusCentre,
            onCanvi: (v) => setState(() => f = f.copyWith(tipusCentre: () => v)),
          ),
          const SizedBox(height: 28),

          Row(children: [
            TextButton(
              onPressed: () => setState(() => f = Filtres(text: f.text)),
              child: const Text('Neteja'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(f),
              icon: const Icon(Icons.check),
              label: const Text('Mostra els resultats'),
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
