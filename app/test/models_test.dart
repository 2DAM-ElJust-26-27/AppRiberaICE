import 'package:connectant_ribera/dades/api_ribera.dart';
import 'package:connectant_ribera/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CentreResum llegeix el JSON de l\'API i respecta les coordenades nul·les', () {
    final c = CentreResum.fromJson({
      'id': 5,
      'codi': 'CEN05',
      'nom': 'CEAM de Cullera',
      'tipus_centre': {'id': 6, 'codi': 'TC06', 'nom': 'Centre d’atenció especialitzada'},
      'municipi': {'id': 40, 'codi': 'MUN40', 'nom': 'Cullera'},
      'adreca': 'C/ la Bega, 14',
      'codi_postal': '46400',
      'latitud': 39.1615,
      'longitud': -0.2537,
      'precisio_punt': 'punt_publicat',
    });
    expect(c.tePunt, isTrue);
    expect(c.adrecaCompleta, 'C/ la Bega, 14, 46400 Cullera');

    final sensePunt = CentreResum.fromJson({'id': 1, 'nom': 'X', 'latitud': null, 'longitud': null});
    expect(sensePunt.tePunt, isFalse);
    expect(sensePunt.adrecaCompleta, isNull);
  });

  test('Contacte classifica telèfon, correu i web', () {
    expect(const Contacte(tipus: 'telèfon', valor: '961719435').classe, TipusContacte.telefon);
    expect(const Contacte(tipus: 'correu', valor: 'a@b.es').classe, TipusContacte.correu);
    expect(const Contacte(tipus: 'web', valor: 'https://x.org').classe, TipusContacte.web);
  });

  test('Filtres genera només els paràmetres actius', () {
    const f = Filtres(text: '  alzheimer ', municipiId: 47, collectiu: 'COL_MAJORS');
    expect(f.parametres, {'q': 'alzheimer', 'municipi': '47', 'collectiu': 'COL_MAJORS'});
    expect(f.nombreActius, 2);
    expect(f.copyWith(municipiId: () => null).municipiId, isNull);
    expect(f.copyWith(text: 'x').collectiu, 'COL_MAJORS');
  });

  test('Franja mostra el dia ISO en valencià', () {
    expect(const Franja(diaSetmana: 1, horaInici: '09:00', horaFi: '14:00').text, 'dilluns 09:00–14:00');
  });
}
