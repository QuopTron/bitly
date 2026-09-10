// ─────────────────────────────────────────────────────────────
// utilidades_carga.dart — Patrón "caché local primero, luego
// fetch remoto" para detalles (álbum/playlist/artista). Llama a
// [getLocal] primero (p.ej. CacheDetalle); si es null/vacío, llama a
// [fetchRemoto] como respaldo (el backend itera todas las
// extensiones cuando source viene vacío).
// Se conecta con: caches de detalle + backend Go (fetches).
// Parte del flujo: detalle de álbum/playlist/artista.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

/// Carga un detalle con patrón caché-primero-respaldo-remoto.
/// Devuelve el [T] parseado o null ante cualquier error.
Future<T?> cargarDetalleConRespaldo<T>({
  required String id,
  required String source,
  required Future<String?> Function(String id) obtenerLocal,
  required Future<String> Function(String id, String source) obtenerRemoto,
  required T Function(Map<String, dynamic> json) desdeJson,
}) async {
  try {
    var json = await obtenerLocal(id);
    if (json == null || json.isEmpty || json == '{}') {
      json = await obtenerRemoto(id, source);
    }
    if (json.isEmpty || json == '{}') return null;
    return desdeJson(jsonDecode(json) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}