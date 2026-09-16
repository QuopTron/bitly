// ─────────────────────────────────────────────────────────────
// historial_compartidos_puro.dart — La parte del historial de
// compartidos que NO toca almacenamiento: ordenar, no repetir, topar
// y (de)serializar. Vive aparte para poder probarla sin base de datos.
//
// Se conecta con: servicio_historial_compartidos (lo usa) y su test.
// Parte del flujo: enlace recibido → historial "quién te compartió qué".
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'compartido_recibido.dart';

/// Tope de entradas guardadas.
const int maximoCompartidos = 50;

/// Historial nuevo con [nuevo] arriba: sin repetir la misma canción del
/// mismo emisor (que se reubica) y recortado al tope.
List<CompartidoRecibido> nuevoHistorial(
  List<CompartidoRecibido> actuales,
  CompartidoRecibido nuevo, {
  int maximo = maximoCompartidos,
}) {
  final lista = [nuevo, ...actuales.where((e) => e.clave != nuevo.clave)];
  return lista.take(maximo).toList();
}

/// Historial a JSON (lo que se guarda en los ajustes).
String codificarHistorial(List<CompartidoRecibido> items) =>
    jsonEncode(items.map((e) => e.aJson()).toList());

/// JSON guardado → historial. Tolera vacío, basura y entradas incompletas.
List<CompartidoRecibido> decodificarHistorial(String? crudo) {
  if (crudo == null || crudo.trim().isEmpty) return [];
  try {
    final json = jsonDecode(crudo);
    if (json is! List) return [];
    return json
        .whereType<Map>()
        .map((e) => CompartidoRecibido.desdeJson(Map<String, dynamic>.from(e)))
        .where((e) => e.datos.valido)
        .toList();
  } catch (_) {
    return [];
  }
}
