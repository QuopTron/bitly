// ─────────────────────────────────────────────────────────────
// servicio_historial_compartidos.dart — Guarda quién te compartió qué.
//
// Qué hace: cada vez que llega un enlace de Bitly (por deep link o
// compartiéndolo a la app) anota el emisor y la canción. La pestaña
// "Compartidos" de Ajustes las lista.
//
// Detalles: se guarda como JSON en un solo ajuste (`compartidos_recibidos`),
// más nuevo primero, sin repetir la misma canción del mismo emisor y con un
// tope de 50 entradas. El orden/dedupe/tope vive en
// historial_compartidos_puro (probado sin base de datos).
//
// Se conecta con: datos_compartido + historial_compartidos_puro +
// CacheAjustes.
// Parte del flujo: enlace recibido → historial "quién te compartió qué".
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

import '../../../app/inyeccion.dart' as di;
import '../../cache/almacenes/cache_ajustes.dart';
import 'compartido_recibido.dart';
import 'datos_compartido.dart';
import 'historial_compartidos_puro.dart';

/// Historial de compartidos recibidos.
class ServicioHistorialCompartidos {
  ServicioHistorialCompartidos._();
  static final ServicioHistorialCompartidos instance =
      ServicioHistorialCompartidos._();

  /// Clave del ajuste donde vive el JSON.
  static const clave = 'compartidos_recibidos';

  CacheAjustes get _cache => di.sl<CacheAjustes>();

  /// Anota un compartido recién recibido (sin bloquear a quien lo llama).
  Future<void> registrar(DatosCompartido datos) async {
    if (!datos.valido) return;
    try {
      final nuevo = CompartidoRecibido(datos: datos, fecha: DateTime.now());
      final lista = nuevoHistorial(await cargar(), nuevo);
      await _cache.guardarAjuste(clave, codificarHistorial(lista));
    } catch (e) {
      debugPrint("[Compartidos] no se pudo guardar: $e");
    }
  }

  /// Historial completo, del más nuevo al más viejo.
  Future<List<CompartidoRecibido>> cargar() async {
    try {
      return decodificarHistorial(await _cache.getAjuste(clave));
    } catch (e) {
      debugPrint("[Compartidos] no se pudo leer: $e");
      return [];
    }
  }

  /// Borra el historial (botón de la pestaña Compartidos).
  Future<void> limpiar() async {
    try {
      await _cache.guardarAjuste(clave, codificarHistorial(const []));
    } catch (e) {
      debugPrint("[Compartidos] no se pudo limpiar: $e");
    }
  }
}
