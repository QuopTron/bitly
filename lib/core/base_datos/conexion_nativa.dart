// ─────────────────────────────────────────────────────────────
// conexion_nativa.dart — Conexión de la base local en las
// plataformas nativas (Android/iOS/escritorio): un archivo SQLite
// real en el directorio de documentos de la app.
//
// Se elige por import condicional desde app_database.dart; el web
// usa conexion_web.dart porque `drift/native.dart` depende de
// dart:ffi, que NO existe en el navegador (era justo el error que
// rompía la compilación del PWA).
//
// Se conecta con: app_database.dart (import condicional).
// Parte del flujo: arranque (AppDatabase.create).
// ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Abre la base local como archivo SQLite, con la E/S en un isolate
/// aparte para no bloquear el hilo de la UI.
Future<QueryExecutor> abrirConexion() async {
  final dir = await getApplicationDocumentsDirectory();
  await dir.create(recursive: true);
  final archivo = File(p.join(dir.path, 'bitly_cache.db'));
  return NativeDatabase.createInBackground(archivo);
}
