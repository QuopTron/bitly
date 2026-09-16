// ─────────────────────────────────────────────────────────────
// isrc_mixin.dart — Mixin RPC de identidad por ISRC.
//
// Qué hace: manda un ISRC a Go (`resolveISRC`), que busca en todas las
// extensiones con `isrc:"..."` —match exacto, sin adivinar por
// nombre— y devuelve la primera canción real encontrada.
//
// Por qué existe: es la vía rápida para reproducir un enlace
// compartido. Antes había que re-buscar por nombre, que es donde se
// cuelan versiones en vivo, remixes o el track equivocado.
//
// Se conecta con: backend_go (RPC resolveISRC) + modelos/item_feed.
// Parte del flujo: enlaces compartidos → canción reproducible.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import '../../modelos/feed/item_feed.dart';
import '../nucleo/contrato_backend.dart';

/// Resolución de canciones por ISRC contra el backend Go.
mixin IsrcMixin on BackendService {
  @override
  Future<ItemFeed?> resolverIsrc(String isrc) async {
    final codigo = isrc.trim();
    if (codigo.isEmpty) return null;
    try {
      final resultado = await rpcCall('resolveISRC', {'isrc': codigo});
      final raw = resultado is String ? jsonDecode(resultado) : resultado;
      if (raw is! List) return null;
      for (final crudo in raw) {
        if (crudo is! Map) continue;
        final item = ItemFeed.desdeJson(Map<String, dynamic>.from(crudo));
        if (item.name.isNotEmpty) return item;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
