import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import 'comuns.dart';

/// Obri un enllaç extern (telèfon, correu o web) i avisa si no és possible.
Future<void> obriEnllac(BuildContext context, Uri uri) async {
  final missatger = ScaffoldMessenger.of(context);
  bool ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok) missatger.showSnackBar(SnackBar(content: Text('No s\'ha pogut obrir $uri')));
}

Uri? uriContacte(Contacte c) {
  final v = c.valor.trim();
  switch (c.classe) {
    case TipusContacte.telefon:
      return Uri(scheme: 'tel', path: v.replaceAll(RegExp(r'[^0-9+]'), ''));
    case TipusContacte.correu:
      return Uri(scheme: 'mailto', path: v);
    case TipusContacte.web:
      return Uri.tryParse(v.startsWith('http') ? v : 'https://$v');
    case TipusContacte.altre:
      return null;
  }
}

IconData iconaContacte(Contacte c) => switch (c.classe) {
      TipusContacte.telefon => Icons.call_outlined,
      TipusContacte.correu => Icons.mail_outline,
      TipusContacte.web => Icons.language,
      TipusContacte.altre => Icons.contact_page_outlined,
    };

/// Llista de contactes clicables.
class LlistaContactes extends StatelessWidget {
  final List<Contacte> contactes;

  const LlistaContactes(this.contactes, {super.key});

  @override
  Widget build(BuildContext context) {
    if (contactes.isEmpty) return const Nota('No consten canals de contacte propis.');
    return Column(children: [
      for (final c in contactes)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(iconaContacte(c)),
          title: Text(c.valor),
          subtitle: Text(c.tipus),
          trailing: uriContacte(c) == null ? null : const Icon(Icons.open_in_new, size: 18),
          onTap: uriContacte(c) == null ? null : () => obriEnllac(context, uriContacte(c)!),
        ),
    ]);
  }
}

/// Horaris: text documental i franges, si n'hi ha.
class LlistaHoraris extends StatelessWidget {
  final List<Horari> horaris;

  const LlistaHoraris(this.horaris, {super.key});

  @override
  Widget build(BuildContext context) {
    if (horaris.isEmpty) return const Nota('No consta cap horari.');
    final t = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final h in horaris)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (h.descripcio != null) Text(_capitalitza(h.descripcio!), style: t.textTheme.bodyMedium),
            for (final f in h.franges) Text(f.text, style: t.textTheme.bodySmall),
          ]),
        ),
      if (horaris.every((h) => h.franges.isEmpty))
        const Nota('Horari documental: no hi ha franges horàries confirmades. Consulteu-ho abans d\'anar-hi.'),
    ]);
  }

  static String _capitalitza(String s) {
    final t = s.trim().toLowerCase();
    return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
  }
}

/// Mostra la font de procedència d'una dada (enllaç si és una web).
class TextFont extends StatelessWidget {
  final Font? font;
  final String prefix;

  const TextFont(this.font, {super.key, this.prefix = 'Font'});

  @override
  Widget build(BuildContext context) {
    final f = font;
    if (f == null) return const SizedBox.shrink();
    final t = Theme.of(context);
    final estil = t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant);
    if (f.esEnllac) {
      return InkWell(
        onTap: () => obriEnllac(context, Uri.parse(f.referencia!)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text('$prefix: ${f.referencia}', style: estil?.copyWith(decoration: TextDecoration.underline)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text('$prefix: ${f.referencia ?? f.codi}', style: estil),
    );
  }
}
