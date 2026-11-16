import 'package:flutter/widgets.dart';

import '../dades/api_ribera.dart';
import '../models/models.dart';
import 'assistent_estat.dart';

enum EstatCarrega { inicial, carregant, llest, error }

/// Pestanyes de la pantalla principal.
enum Pestanya { serveis, centres, entitats }

/// Catàlegs, municipis i entitats (dades que comparteixen totes les pestanyes).
class DirectoriEstat extends ChangeNotifier {
  final ApiRibera api;

  DirectoriEstat(this.api);

  List<Municipi> municipis = [];
  Catalegs catalegs = const Catalegs();
  EstatCarrega estatCatalegs = EstatCarrega.inicial;
  String? errorCatalegs;

  List<EntitatResum> entitats = [];
  EstatCarrega estatEntitats = EstatCarrega.inicial;
  String? errorEntitats;

  Future<void> inicialitza() async {
    estatCatalegs = EstatCarrega.carregant;
    notifyListeners();
    try {
      final res = await Future.wait([api.municipis(), api.catalegs()]);
      municipis = res[0] as List<Municipi>;
      catalegs = res[1] as Catalegs;
      estatCatalegs = EstatCarrega.llest;
    } catch (e) {
      estatCatalegs = EstatCarrega.error;
      errorCatalegs = e.toString();
    }
    notifyListeners();
  }

  Future<void> carregaEntitats() async {
    estatEntitats = EstatCarrega.carregant;
    errorEntitats = null;
    notifyListeners();
    try {
      entitats = await api.entitats();
      estatEntitats = EstatCarrega.llest;
    } catch (e) {
      estatEntitats = EstatCarrega.error;
      errorEntitats = e.toString();
    }
    notifyListeners();
  }

  String? nomMunicipi(int? id) {
    if (id == null) return null;
    for (final m in municipis) {
      if (m.id == id) return m.nom;
    }
    return null;
  }

  String? nomCataleg(List<Ref> llista, String? codi) {
    if (codi == null) return null;
    for (final r in llista) {
      if (r.codi == codi) return r.nom;
    }
    return codi;
  }
}

/// Pestanya Centres: filtres de serveis i centres on es presten.
class CentresEstat extends ChangeNotifier {
  final ApiRibera api;

  CentresEstat(this.api);

  Filtres filtres = const Filtres();

  /// Centres que compleixen els filtres (amb i sense coordenades).
  List<CentreResum> centres = [];

  /// Serveis que compleixen els filtres (excepte el de servei): opcions del selector de servei.
  List<ServeiResum> serveisDisponibles = [];

  EstatCarrega estat = EstatCarrega.inicial;
  String? error;
  int _peticio = 0;

  List<CentreResum> get ambPunt => centres.where((c) => c.tePunt).toList();

  ServeiResum? get serveiSeleccionat {
    for (final s in serveisDisponibles) {
      if (s.id == filtres.serveiId) return s;
    }
    return null;
  }

  Future<void> carrega() async {
    final num = ++_peticio;
    estat = EstatCarrega.carregant;
    error = null;
    notifyListeners();
    try {
      final res = await Future.wait([api.centres(filtres), api.serveis(filtres)]);
      if (num != _peticio) return;
      centres = res[0] as List<CentreResum>;
      serveisDisponibles = res[1] as List<ServeiResum>;
      estat = EstatCarrega.llest;
    } catch (e) {
      if (num != _peticio) return;
      estat = EstatCarrega.error;
      error = e.toString();
    }
    notifyListeners();
  }

  void aplica(Filtres nous) {
    filtres = nous;
    carrega();
  }

  void neteja() => aplica(const Filtres());
}

/// Fa accessibles els estats a tot l'arbre (sense Riverpod ni Provider).
/// Els widgets escolten cada estat amb [ListenableBuilder].
class EstatApp extends InheritedWidget {
  final DirectoriEstat directori;
  final CentresEstat centres;
  final AssistentEstat assistent;
  final ValueNotifier<Pestanya> pestanya;

  const EstatApp({
    super.key,
    required this.directori,
    required this.centres,
    required this.assistent,
    required this.pestanya,
    required super.child,
  });

  static EstatApp of(BuildContext context) => context.getInheritedWidgetOfExactType<EstatApp>()!;

  @override
  bool updateShouldNotify(EstatApp oldWidget) => false;
}
