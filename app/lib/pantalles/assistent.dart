import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../widgets.dart';
import 'fitxa_servei.dart';

/// Pestanya Serveis: l'assistent «Carlos Collado» fa tres preguntes
/// i va filtrant la llista de serveis.
class PantallaAssistent extends StatefulWidget {
  const PantallaAssistent({super.key});

  @override
  State<PantallaAssistent> createState() => _PantallaAssistentState();
}

class _PantallaAssistentState extends State<PantallaAssistent> {
  final Future<List<Servei>> _serveis = getServeis();

  int _pas = 0;         // 0, 1 o 2: pregunta actual. 3: resultats
  String? _collectiu;   // null = qualsevol
  String? _municipi;
  String? _tipus;

  static const _preguntes = [
    'Per a qui és l\'ajuda?',
    'En quin municipi la necessites?',
    'Quin tipus de lloc prefereixes?',
  ];

  /// Serveis que encaixen amb les respostes donades fins ara.
  List<Servei> _filtra(List<Servei> serveis) {
    return serveis.where((s) {
      if (_collectiu != null && !s.collectius.contains(_collectiu)) return false;
      if (_municipi != null && !s.municipis.contains(_municipi)) return false;
      if (_tipus != null && !s.tipus.contains(_tipus)) return false;
      return true;
    }).toList();
  }

  /// Opcions de la pregunta actual i quants serveis té cadascuna.
  /// Exemple: {Gent gran: 5, Infància: 3}
  Map<String, int> _opcions(List<Servei> serveis) {
    final recomptes = <String, int>{};
    for (final s in serveis) {
      final List<String> valors;
      if (_pas == 0) {
        valors = s.collectius;
      } else if (_pas == 1) {
        valors = s.municipis;
      } else {
        valors = s.tipus;
      }
      for (final v in valors) {
        recomptes[v] = (recomptes[v] ?? 0) + 1;
      }
    }
    return recomptes;
  }

  void _respon(String? valor) {
    setState(() {
      if (_pas == 0) _collectiu = valor;
      if (_pas == 1) _municipi = valor;
      if (_pas == 2) _tipus = valor;
      _pas++;
    });
  }

  void _reinicia() {
    setState(() {
      _pas = 0;
      _collectiu = null;
      _municipi = null;
      _tipus = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Serveis')),
      body: ambDades(_serveis, (serveis) {
        final candidats = _filtra(serveis);
        final opcions = _opcions(candidats);
        // Parem de preguntar si ja hem fet les 3, si queden pocs serveis o si no hi ha opcions
        final acabat = _pas >= 3 || candidats.length <= 3 || opcions.isEmpty;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const ListTile(
              leading: CircleAvatar(child: Icon(Icons.support_agent)),
              title: Text('Hola, sóc en Carlos Collado'),
              subtitle: Text('Et faré unes preguntes per trobar el servei que necessites.'),
            ),
            const SizedBox(height: 16),
            if (acabat) ..._resultats(candidats) else ..._pregunta(opcions, candidats.length),
          ],
        );
      }),
    );
  }

  List<Widget> _pregunta(Map<String, int> opcions, int total) {
    return [
      Text(_preguntes[_pas], style: Theme.of(context).textTheme.titleLarge),
      Text('Ara mateix encaixen $total serveis'),
      const SizedBox(height: 8),
      for (final opcio in opcions.keys)
        Card(
          child: ListTile(
            title: Text(opcio),
            trailing: Text('${opcions[opcio]}'),
            onTap: () => _respon(opcio),
          ),
        ),
      TextButton(onPressed: () => _respon(null), child: const Text('Qualsevol')),
    ];
  }

  List<Widget> _resultats(List<Servei> serveis) {
    return [
      Text('Et recomane aquests serveis:', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      for (final s in serveis)
        Card(
          child: ListTile(
            title: Text(s.nom),
            subtitle: Text(s.descripcio ?? ''),
            onTap: () => obri(context, FitxaServei(s.id)),
          ),
        ),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: _reinicia, child: const Text('Torna a començar')),
    ];
  }
}
