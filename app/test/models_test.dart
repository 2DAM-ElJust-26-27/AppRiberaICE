import 'package:connectant_ribera/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Un centre sense coordenades no té ubicació', () {
    final centre = Centre.fromJson({'id': 1, 'nom': 'CEAM', 'latitud': null, 'longitud': null});
    expect(centre.teUbicacio, false);
  });

  test('Un centre amb coordenades sí que té ubicació', () {
    final centre = Centre.fromJson({'id': 1, 'nom': 'CEAM', 'latitud': 39.16, 'longitud': -0.25});
    expect(centre.teUbicacio, true);
    expect(centre.latitud, 39.16);
  });

  test('Un servei llig les seues llistes', () {
    final servei = Servei.fromJson({
      'id': 2,
      'nom': 'Ajuda a domicili',
      'collectius': ['Gent gran'],
      'municipis': ['Cullera'],
      'tipus': [],
    });
    expect(servei.collectius, ['Gent gran']);
    expect(servei.tipus, isEmpty);
  });
}
