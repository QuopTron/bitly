// ─────────────────────────────────────────────────────────────
// conexion_web.dart — Conexión de la base local en el navegador
// (PWA): SQLite compilado a WebAssembly, guardado en el
// almacenamiento del navegador (OPFS/IndexedDB según soporte).
//
// Por qué existe: `drift/native.dart` usa dart:ffi y el navegador
// no lo tiene, así que la versión web NO puede compartir la
// conexión nativa. drift resuelve esto con un módulo wasm y un
// worker, que se sirven como archivos estáticos desde web/:
//   · sqlite3.wasm     (SQLite compilado a WebAssembly)
//   · drift_worker.js  (el worker que abre la base y atiende las
//                       consultas fuera del hilo de la UI)
//
// Las versiones de esos dos archivos tienen que coincidir con las
// de pubspec.lock (sqlite3 y drift); al subir cualquiera de los dos
// paquetes hay que volver a bajarlas de sus releases oficiales.
//
// Se conecta con: app_database.dart (import condicional).
// Parte del flujo: arranque (AppDatabase.create) en web.
// ─────────────────────────────────────────────────────────────

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Abre la base local en el navegador usando drift sobre wasm.
///
/// [WasmDatabase.open] sondea el navegador y elige el mejor backend
/// disponible (OPFS, IndexedDB o memoria), así que el mismo código
/// funciona en Chrome, Firefox y Safari.
Future<QueryExecutor> abrirConexion() async {
  final resultado = await WasmDatabase.open(
    databaseName: 'bitly_cache',
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
  );
  return resultado.resolvedExecutor;
}
