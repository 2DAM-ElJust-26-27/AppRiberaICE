import 'package:flutter/material.dart';

import 'pantalles/detall_centre.dart';
import 'pantalles/detall_entitat.dart';
import 'pantalles/detall_servei.dart';

/// Obri la fitxa d'un servei.
void obriServei(BuildContext context, int id) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetallServei(id: id)));

/// Obri la fitxa d'un centre.
void obriCentre(BuildContext context, int id) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetallCentre(id: id)));

/// Obri la fitxa d'una entitat.
void obriEntitat(BuildContext context, int id) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetallEntitat(id: id)));
