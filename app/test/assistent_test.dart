import 'package:connectant_ribera/dades/api_ribera.dart';
import 'package:connectant_ribera/logica/assistent.dart';
import 'package:connectant_ribera/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// API falsa: filtra una llista fixa de serveis en memòria.
class ApiFalsa extends ApiRibera {
  ApiFalsa() : super(base: 'http://fals');

  static const majors = Ref(codi: 'COL_MAJORS', nom: 'Persones majors');
  static const sm = Ref(codi: 'COL_SM', nom: 'Salut mental');
  static const sueca = Ref(id: 47, nom: 'Sueca');
  static const cullera = Ref(id: 40, nom: 'Cullera');
  static const residencia = Ref(codi: 'TC04', nom: 'Centre residencial');
  static const dia = Ref(codi: 'TC03', nom: 'Centre de dia');

  final serveisFixos = <ServeiResum>[
    for (var i = 1; i <= 4; i++)
      ServeiResum(id: i, nom: 'Majors $i', collectius: const [majors], municipis: const [sueca], tipusCentre: [i.isEven ? residencia : dia]),
    const ServeiResum(id: 10, nom: 'Majors Cullera', collectius: [majors], municipis: [cullera], tipusCentre: [dia]),
    const ServeiResum(id: 20, nom: 'Salut mental Sueca', collectius: [sm], municipis: [sueca]),
  ];

  @override
  Future<List<ServeiResum>> serveis(Filtres f) async => serveisFixos.where((s) {
        if (f.collectiu != null && !s.collectius.any((c) => c.codi == f.collectiu)) return false;
        if (f.municipiId != null && !s.municipis.any((m) => m.id == f.municipiId)) return false;
        if (f.tipusCentre != null && !s.tipusCentre.any((t) => t.codi == f.tipusCentre)) return false;
        if (f.text.isNotEmpty && !s.nom.toLowerCase().contains(f.text.toLowerCase())) return false;
        return true;
      }).toList();
}

void main() {
  late AssistentEstat a;

  setUp(() async {
    a = AssistentEstat(ApiFalsa(), pausa: Duration.zero);
    await a.comenca();
  });

  test('saluda com a Carlos Collado i pregunta per a qui és l\'ajuda', () {
    expect(a.missatges.first.text, contains('Carlos Collado'));
    expect(a.pas, Pas.collectiu);
    expect(a.opcionsActives.map((o) => o.text), containsAll(['Persones majors', 'Salut mental']));
  });

  test('guia per col·lectiu → municipi → tipus i mostra els resultats', () async {
    await a.tria(a.opcionsActives.firstWhere((o) => o.valor == 'COL_MAJORS'));
    expect(a.pas, Pas.municipi);
    // Només s'ofereixen municipis amb resultats
    expect(a.opcionsActives.map((o) => o.text), containsAll(['Cullera', 'Sueca', 'Qualsevol lloc']));

    await a.tria(a.opcionsActives.firstWhere((o) => o.text == 'Sueca'));
    expect(a.pas, Pas.tipusCentre);

    await a.tria(a.opcionsActives.firstWhere((o) => o.valor == 'TC04'));
    expect(a.pas, Pas.resultats);
    final resultats = a.missatges.lastWhere((m) => m.serveis.isNotEmpty).serveis;
    expect(resultats.map((s) => s.id), [2, 4]);
    expect(a.opcionsActives.any((o) => o.accio == Accio.veureMapa), isTrue);
  });

  test('amb pocs resultats no fa més preguntes', () async {
    await a.tria(a.opcionsActives.firstWhere((o) => o.valor == 'COL_SM'));
    expect(a.pas, Pas.resultats);
  });

  test('text lliure busca directament', () async {
    await a.escriu('cullera');
    expect(a.missatges.lastWhere((m) => m.serveis.isNotEmpty).serveis.single.id, 10);
  });

  test('sense resultats ho diu i ofereix tornar a començar', () async {
    await a.escriu('res de res');
    expect(a.missatges.last.text, contains('No he trobat'));
    expect(a.opcionsActives.any((o) => o.accio == Accio.reinicia), isTrue);
  });
}
