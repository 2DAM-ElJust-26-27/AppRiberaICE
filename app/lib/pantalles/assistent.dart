import 'package:flutter/material.dart';

import '../dades/api_ribera.dart';
import '../estat/assistent_estat.dart';
import '../estat/estat_app.dart';
import '../widgets/targetes.dart';

/// Pestanya Serveis: xat guiat amb l'assistent «Carlos Collado».
class PantallaAssistent extends StatefulWidget {
  const PantallaAssistent({super.key});

  @override
  State<PantallaAssistent> createState() => _PantallaAssistentState();
}

class _PantallaAssistentState extends State<PantallaAssistent> {
  final _scroll = ScrollController();
  final _text = TextEditingController();
  int _vistos = 0;

  @override
  void dispose() {
    _scroll.dispose();
    _text.dispose();
    super.dispose();
  }

  void _baixa() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _tria(Opcio o) {
    final estat = EstatApp.of(context);
    if (o.accio == Accio.veureMapa) {
      final f = estat.assistent.filtres;
      final res = estat.assistent.resultats;
      estat.centres.aplica(Filtres(
        collectiu: f.collectiu,
        municipiId: f.municipiId,
        tipusCentre: f.tipusCentre,
        serveiId: res.length == 1 ? res.first.id : null,
      ));
      estat.pestanya.value = Pestanya.centres;
    }
    estat.assistent.tria(o);
  }

  void _envia() {
    final t = _text.text;
    _text.clear();
    EstatApp.of(context).assistent.escriu(t);
  }

  @override
  Widget build(BuildContext context) {
    final a = EstatApp.of(context).assistent;
    return ListenableBuilder(
      listenable: a,
      builder: (context, _) {
        if (a.missatges.length != _vistos || a.escrivint) {
          _vistos = a.missatges.length;
          _baixa();
        }
        final opcions = a.opcionsActives;
        return Column(children: [
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  children: [
                    for (var i = 0; i < a.missatges.length; i++)
                      _Bombolla(
                        missatge: a.missatges[i],
                        mostraAvatar: a.missatges[i].autor == Autor.assistent &&
                            (i == 0 || a.missatges[i - 1].autor != Autor.assistent),
                      ),
                    if (a.escrivint) const _Escrivint(),
                    if (!a.escrivint && opcions.isNotEmpty) _Opcions(opcions: opcions, onTria: _tria),
                  ],
                ),
              ),
            ),
          ),
          _BarraText(controlador: _text, onEnvia: _envia, actiu: !a.escrivint),
        ]);
      },
    );
  }
}

class AvatarCarlos extends StatelessWidget {
  final double radi;

  const AvatarCarlos({super.key, this.radi = 18});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Tooltip(
      message: '${AssistentEstat.nom} · assistent del directori',
      child: CircleAvatar(
        radius: radi,
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        child: Text('CC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: radi * 0.75)),
      ),
    );
  }
}

class _Bombolla extends StatelessWidget {
  final Missatge missatge;
  final bool mostraAvatar;

  const _Bombolla({required this.missatge, required this.mostraAvatar});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    final esUsuari = missatge.autor == Autor.usuari;

    final bombolla = missatge.text.isEmpty
        ? null
        : Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: esUsuari ? c.primary : c.surfaceContainerHigh,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(esUsuari ? 18 : 4),
                bottomRight: Radius.circular(esUsuari ? 4 : 18),
              ),
            ),
            child: Text(missatge.text,
                style: t.textTheme.bodyMedium?.copyWith(color: esUsuari ? c.onPrimary : c.onSurface)),
          );

    if (esUsuari) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, left: 48),
        child: Align(alignment: Alignment.centerRight, child: bombolla),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 40, child: mostraAvatar ? const AvatarCarlos() : null),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (mostraAvatar)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 2),
                child: Text(AssistentEstat.nom, style: t.textTheme.labelMedium?.copyWith(color: c.primary)),
              ),
            if (bombolla != null) bombolla,
            if (missatge.serveis.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final s in missatge.serveis)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: TargetaServei(s)),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _Escrivint extends StatelessWidget {
  const _Escrivint();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        const SizedBox(width: 40, child: AvatarCarlos()),
        const SizedBox(width: 8),
        Text('${AssistentEstat.nom} està escrivint…',
            style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
      ]),
    );
  }
}

class _Opcions extends StatelessWidget {
  final List<Opcio> opcions;
  final ValueChanged<Opcio> onTria;

  const _Opcions({required this.opcions, required this.onTria});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 48),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in opcions)
          ActionChip(
            avatar: switch (o.accio) {
              Accio.reinicia => const Icon(Icons.restart_alt, size: 18),
              Accio.veureMapa => const Icon(Icons.map_outlined, size: 18),
              Accio.llevaMunicipi => const Icon(Icons.public, size: 18),
              _ => null,
            },
            label: Text(o.recompte == null ? o.text : '${o.text}  (${o.recompte})'),
            side: BorderSide(color: c.primary.withValues(alpha: 0.5)),
            onPressed: () => onTria(o),
          ),
      ]),
    );
  }
}

class _BarraText extends StatelessWidget {
  final TextEditingController controlador;
  final VoidCallback onEnvia;
  final bool actiu;

  const _BarraText({required this.controlador, required this.onEnvia, required this.actiu});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Material(
      color: c.surface,
      elevation: 2,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: controlador,
                    enabled: actiu,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onEnvia(),
                    decoration: const InputDecoration(hintText: 'Escriu què necessites (p. ex. «alzheimer»)'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(tooltip: 'Envia', onPressed: actiu ? onEnvia : null, icon: const Icon(Icons.send)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
