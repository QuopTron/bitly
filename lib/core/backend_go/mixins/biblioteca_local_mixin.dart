// ─────────────────────────────────────────────────────────────
// biblioteca_local_mixin.dart — Mixin de la música PROPIA del
// usuario: importar una carpeta, indexarla por ISRC y saber qué
// canciones ya tiene para no volver a descargarlas.
// Se conecta con: backend_go (importarBibliotecaLocal,
// faltantesLocales, rutaLocalIsrc).
// Parte del flujo: importación local (compras de Amazon, archivos
// de iTunes Match, FLAC propios) + dedupe de descargas.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import '../nucleo/contrato_backend.dart';

/// RPCs de la biblioteca local: importación y dedupe por ISRC.
mixin BibliotecaLocalMixin on BackendService {
  @override
  Future<Map<String, dynamic>> importarBibliotecaLocal({
    required String directorio,
  }) async {
    try {
      final bruto = await rpcCall('importarBibliotecaLocal', {
        'directory': directorio,
      });
      return _comoMapa(bruto);
    } catch (_) {
      return const {};
    }
  }

  @override
  Future<List<String>> faltantesLocales({required List<String> isrcs}) async {
    if (isrcs.isEmpty) return const [];
    try {
      final bruto = await rpcCall('faltantesLocales', {
        'isrcs': jsonEncode(isrcs),
      });
      final decodificado = _decodificar(bruto);
      if (decodificado is List) {
        return decodificado.map((e) => e.toString()).toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<String?> rutaLocalIsrc({required String isrc}) async {
    if (isrc.isEmpty) return null;
    try {
      final bruto = await rpcCall('rutaLocalIsrc', {'isrc': isrc});
      final decodificado = _decodificar(bruto);
      if (decodificado is Map) {
        final ruta = decodificado['filePath']?.toString() ?? '';
        return ruta.isEmpty ? null : ruta;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// El puente devuelve strings JSON; los normaliza sin romper si viene vacío.
  dynamic _decodificar(dynamic bruto) {
    if (bruto is! String || bruto.isEmpty) return null;
    try {
      return jsonDecode(bruto);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _comoMapa(dynamic bruto) {
    final decodificado = _decodificar(bruto);
    if (decodificado is Map<String, dynamic>) return decodificado;
    if (decodificado is Map) return Map<String, dynamic>.from(decodificado);
    return const {};
  }
}
