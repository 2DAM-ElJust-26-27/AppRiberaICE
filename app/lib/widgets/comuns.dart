import 'package:flutter/material.dart';

import '../models/models.dart';

/// Marc amb marge, vora i cantons arrodonits per al contingut principal d'una pestanya.
class Marc extends StatelessWidget {
  final Widget child;
  final EdgeInsets marge;

  const Marc({super.key, required this.child, this.marge = const EdgeInsets.fromLTRB(24, 4, 24, 24)});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    const radi = BorderRadius.all(Radius.circular(16));
    return Padding(
      padding: marge,
      child: DecoratedBox(
        position: DecorationPosition.foreground, // la vora es dibuixa damunt del contingut
        decoration: BoxDecoration(borderRadius: radi, border: Border.all(color: c.outlineVariant, width: 1.5)),
        child: ClipRRect(borderRadius: radi, child: child),
      ),
    );
  }
}

/// Indicador de càrrega centrat.
class Carregant extends StatelessWidget {
  const Carregant({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
}

/// Missatge d'estat (buit o error) amb una icona i una acció opcional.
class MissatgeEstat extends StatelessWidget {
  final IconData icona;
  final String titol;
  final String? text;
  final String? accio;
  final VoidCallback? onAccio;

  const MissatgeEstat({super.key, required this.icona, required this.titol, this.text, this.accio, this.onAccio});

  factory MissatgeEstat.error(String missatge, VoidCallback reintenta) => MissatgeEstat(
        icona: Icons.cloud_off_outlined,
        titol: 'No s\'han pogut carregar les dades',
        text: missatge,
        accio: 'Torna-ho a provar',
        onAccio: reintenta,
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icona, size: 56, color: t.colorScheme.outline),
            const SizedBox(height: 16),
            Text(titol, style: t.textTheme.titleMedium, textAlign: TextAlign.center),
            if (text != null) ...[
              const SizedBox(height: 8),
              Text(text!, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
            ],
            if (accio != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(onPressed: onAccio, child: Text(accio!)),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Secció d'una fitxa de detall amb títol.
class Seccio extends StatelessWidget {
  final String titol;
  final IconData? icona;
  final List<Widget> fills;

  const Seccio({super.key, required this.titol, this.icona, required this.fills});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (icona != null) ...[Icon(icona, size: 20, color: t.colorScheme.primary), const SizedBox(width: 8)],
          Text(titol, style: t.textTheme.titleSmall?.copyWith(color: t.colorScheme.primary, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        ...fills,
      ]),
    );
  }
}

/// Fila «etiqueta: valor» per a dades de la fitxa.
class Dada extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const Dada(this.etiqueta, this.valor, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 110,
          child: Text(etiqueta, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        ),
        Expanded(child: SelectableText(valor, style: t.textTheme.bodyMedium)),
      ]),
    );
  }
}

/// Xips de col·lectius.
class XipsCollectius extends StatelessWidget {
  final List<Ref> collectius;
  final int? maxim;

  const XipsCollectius(this.collectius, {super.key, this.maxim});

  @override
  Widget build(BuildContext context) {
    if (collectius.isEmpty) return const SizedBox.shrink();
    final c = Theme.of(context).colorScheme;
    final mostrats = maxim == null ? collectius : collectius.take(maxim!).toList();
    final resta = collectius.length - mostrats.length;
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final r in mostrats)
        Chip(
          label: Text(r.nom),
          labelStyle: TextStyle(fontSize: 12, color: c.onSecondaryContainer),
          backgroundColor: c.secondaryContainer,
          side: BorderSide.none,
          padding: EdgeInsets.zero,
        ),
      if (resta > 0) Chip(label: Text('+$resta'), labelStyle: const TextStyle(fontSize: 12), padding: EdgeInsets.zero),
    ]);
  }
}

/// Text explicatiu discret (avisos sobre la qualitat de les dades).
class Nota extends StatelessWidget {
  final String text;
  final IconData icona;

  const Nota(this.text, {super.key, this.icona = Icons.info_outline});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icona, size: 16, color: t.colorScheme.outline),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant))),
      ]),
    );
  }
}
