import 'package:flutter/material.dart';

import '../dades/api_ribera.dart';
import '../estat/estat_app.dart';
import '../widgets/comuns.dart';

/// Carrega una fitxa (Future) i mostra càrrega, error o el contingut.
class FitxaFutura<T> extends StatefulWidget {
  final String titol;
  final Future<T> Function() carrega;
  final Widget Function(BuildContext, T) construeix;

  const FitxaFutura({super.key, required this.titol, required this.carrega, required this.construeix});

  @override
  State<FitxaFutura<T>> createState() => _FitxaFuturaState<T>();
}

class _FitxaFuturaState<T> extends State<FitxaFutura<T>> {
  late Future<T> _futur = widget.carrega();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titol)),
      body: FutureBuilder<T>(
        future: _futur,
        builder: (context, s) {
          if (s.hasError) {
            return MissatgeEstat.error('${s.error}', () => setState(() => _futur = widget.carrega()));
          }
          if (!s.hasData) return const Carregant();
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [widget.construeix(context, s.data as T)],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Capçalera de fitxa: icona, títol i subtítol.
class CapcaleraFitxa extends StatelessWidget {
  final IconData icona;
  final String titol;
  final String? subtitol;

  const CapcaleraFitxa({super.key, required this.icona, required this.titol, this.subtitol});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(
        radius: 26,
        backgroundColor: t.colorScheme.primaryContainer,
        foregroundColor: t.colorScheme.onPrimaryContainer,
        child: Icon(icona),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SelectableText(titol, style: t.textTheme.headlineSmall),
          if (subtitol != null) ...[
            const SizedBox(height: 4),
            Text(subtitol!, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          ],
        ]),
      ),
    ]);
  }
}

/// Accés a l'API des de les fitxes.
extension ApiContext on BuildContext {
  ApiRibera get api => EstatApp.of(this).directori.api;
}
