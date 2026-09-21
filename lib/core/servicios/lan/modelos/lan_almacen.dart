// ─────────────────────────────────────────────────────────────
// lan_almacen.dart — Dónde vive el vínculo: el token propio de este aparato
// y la lista de pares (con el token de cada uno).
//
// Se guarda como preferencias (clave/valor en JSON), así que no hace falta
// esquema nuevo ni migrar nada. El token propio se genera UNA vez y no se
// cambia: es lo que los otros aparatos ya vinculados tienen guardado.
//
// Si el guardado está roto se arranca vacío: se pierden los vínculos (hay
// que aceptar de nuevo) pero la app funciona y no queda mintiendo.
//
// Se conecta con: servicio_lan (lo usa) + cache_ajustes.
// Parte del flujo: Ajustes → Conexión → biblioteca en tu red.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../cache/almacenes/sistema/cache_ajustes.dart';
import 'lan_modelos.dart';

const String _claveTokenLan = 'lan_token';
const String _claveParesLan = 'lan_pares';

/// El token de este aparato. Se genera una vez y se guarda.
Future<String> asegurarTokenLan(CacheAjustes cache) async {
  final guardado = await cache.getAjuste(_claveTokenLan);
  if (guardado != null && guardado.length >= 16) return guardado;
  final rnd = Random.secure();
  final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
  final token = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  await cache.guardarAjuste(_claveTokenLan, token);
  return token;
}

/// Los pares vinculados (o descubiertos) que quedaron guardados.
Future<List<ParLan>> leerParesLan(CacheAjustes cache) async {
  final raw = await cache.getAjuste(_claveParesLan);
  if (raw == null || raw.isEmpty) return const [];
  try {
    final parsed = jsonDecode(raw);
    if (parsed is! List) return const [];
    return [
      for (final e in parsed)
        if (e is Map<String, dynamic>) ParLan.desdeJson(e),
    ].where((p) => p.id.isNotEmpty).toList();
  } catch (e) {
    debugPrint('[Lan] pares ilegibles: $e');
    return const [];
  }
}

/// Deja guardados los pares (reemplaza la lista anterior).
Future<void> guardarParesLan(CacheAjustes cache, List<ParLan> pares) =>
    cache.guardarAjuste(
      _claveParesLan,
      jsonEncode([for (final p in pares) p.aJson()]),
    );
