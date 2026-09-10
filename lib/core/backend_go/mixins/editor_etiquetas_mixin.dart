// ─────────────────────────────────────────────────────────────
// editor_etiquetas_mixin.dart — Mixin del editor de etiquetas:
// lee/escribe metadatos de archivos de audio y reporta la salud de
// los proveedores, todo vía el backend Go.
// Se conecta con: backend_go (readFileMetadata, writeFileMetadata,
// getProviderHealthStatus).
// Parte del flujo: editor de tags (Mi Espacio) y monitoreo.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:logger/logger.dart';

import '../contrato_backend.dart';

final _log = Logger();

/// Editor de etiquetas — lee/escribe metadatos de audio vía Go.
mixin EditorEtiquetasMixin on BackendService {
  @override
  Future<String> readFileMetadata(String filePath) async {
    try {
      final resultado = await rpcCall('readFileMetadata', {'path': filePath});
      if (resultado is String) return resultado;
      if (resultado is Map) return jsonEncode(resultado);
      return '{}';
    } catch (e) {
      _log.w('[editorEtiquetas] readFileMetadata error: $e');
      return '{}';
    }
  }

  @override
  Future<bool> writeFileMetadata(String filePath, Map<String, String> meta) async {
    try {
      final resultado = await rpcCall('writeFileMetadata', {
        'filePath': filePath,
        'meta': meta,
      });
      if (resultado is Map) return resultado['ok'] == true;
      if (resultado is String && resultado.isNotEmpty) {
        final decodificado = jsonDecode(resultado);
        if (decodificado is Map) return decodificado['ok'] == true;
      }
      return true;
    } catch (e) {
      _log.w('[editorEtiquetas] writeFileMetadata error: $e');
      return false;
    }
  }

  @override
  Future<String> getProviderHealthStatus() async {
    try {
      final resultado = await rpcCall('getProviderHealthStatus');
      if (resultado is String) return resultado;
      if (resultado is List) return jsonEncode(resultado);
      return '[]';
    } catch (e) {
      _log.w('[saludProveedores] getProviderHealthStatus error: $e');
      return '[]';
    }
  }
}