// ─────────────────────────────────────────────────────────────
// enlaces_mixin.dart — Mixin RPC de enlaces compartidos.
//
// Qué hace: manda a Go un enlace de música (Spotify, YouTube, Deezer...) y
// recibe el ítem ya normalizado, listo para reproducir o descargar. Go elige
// la extensión por el patrón de su manifest y llama a su handleUrl.
//
// Se conecta con: backend_go (RPC resolveUrl) + modelos/resultado_enlace.
// Parte del flujo: enlaces compartidos/pegados.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import '../../modelos/resultado_enlace.dart';
import '../nucleo/contrato_backend.dart';

/// Resolución de enlaces de música contra el backend Go.
mixin EnlacesMixin on BackendService {
  @override
  Future<ResultadoEnlace?> resolveUrl(String url) async {
    final enlace = url.trim();
    if (enlace.isEmpty) return null;
    try {
      final resultado = await rpcCall('resolveUrl', {'url': enlace});
      final raw = resultado is String ? jsonDecode(resultado) : resultado;
      if (raw is! Map) return null;
      // Go responde {"error": "..."} cuando ninguna fuente pudo resolverlo.
      if (raw['error'] != null) return null;
      return ResultadoEnlace.desdeJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }
}
