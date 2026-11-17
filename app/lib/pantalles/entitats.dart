import 'package:flutter/material.dart';

import '../dades/api_ribera.dart';
import '../models/models.dart';
import '../widgets/comuns.dart';
import 'detall_entitat.dart';

/// Pestanya Entitats: organitzacions que presten serveis o són titulars/gestores de centres.
class PantallaEntitats extends StatefulWidget {
  const PantallaEntitats({super.key});

  @override
  State<PantallaEntitats> createState() => _PantallaEntitatsState();
}

class _PantallaEntitatsState extends State<PantallaEntitats> {
  String? _forma; // codi de forma jurídica seleccionada (filtre local)

  List<EntitatResum> _entitats = [];
  EstatCarrega _estat = EstatCarrega.carregant;
  String? _error;

  @override
  void initState() {
    super.initState();
    _carrega();
  }

  Future<void> _carrega() async {
    setState(() {
      _estat = EstatCarrega.carregant;
      _error = null;
    });
    try {
      final entitats = await apiRibera.entitats();
      if (!mounted) return;
      setState(() {
        _entitats = entitats;
        _estat = EstatCarrega.llest;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _estat = EstatCarrega.error;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_estat == EstatCarrega.error) return MissatgeEstat.error(_error ?? '', _carrega);
    if (_estat != EstatCarrega.llest) return const Carregant();

        final formes = <String, Ref>{};
        for (final e in _entitats) {
          if (e.formaJuridica?.codi != null) formes[e.formaJuridica!.codi!] = e.formaJuridica!;
        }
        final ordenades = formes.values.toList()..sort((a, b) => a.nom.compareTo(b.nom));
        final llista = _forma == null ? _entitats : _entitats.where((e) => e.formaJuridica?.codi == _forma).toList();

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: RefreshIndicator(
              onRefresh: _carrega,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    ChoiceChip(label: Text('Totes (${_entitats.length})'), selected: _forma == null, onSelected: (_) => setState(() => _forma = null)),
                    for (final f in ordenades)
                      ChoiceChip(
                        label: Text(f.nom),
                        selected: _forma == f.codi,
                        onSelected: (s) => setState(() => _forma = s ? f.codi : null),
                      ),
                  ]),
                  const SizedBox(height: 16),
                  for (final e in llista) ...[_TargetaEntitat(e), const SizedBox(height: 10)],
                  if (llista.isEmpty) const Nota('Cap entitat amb aquesta forma jurídica.'),
                ],
              ),
            ),
          ),
        );
  }
}

class _TargetaEntitat extends StatelessWidget {
  final EntitatResum e;

  const _TargetaEntitat(this.e);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final detalls = [
      if (e.formaJuridica != null) e.formaJuridica!.nom,
      if (e.sector != null) 'Sector ${e.sector!.toLowerCase()}',
      if (e.municipi != null) e.municipi!.nom,
    ].join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: t.colorScheme.secondaryContainer,
          foregroundColor: t.colorScheme.onSecondaryContainer,
          child: const Icon(Icons.apartment_outlined),
        ),
        title: Text(e.nom),
        subtitle: detalls.isEmpty ? null : Text(detalls),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetallEntitat(id: e.id))),
      ),
    );
  }
}
