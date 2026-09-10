// ─────────────────────────────────────────────────────────────
// indicador_descarga.dart — Indicador visual del estado de una
// descarga: punto fijo con color por estado (gris=none/cola,
// naranja=progreso, verde=completado con glow, rojo=interrumpido),
// punto pulsante animado cuando descarga en progreso sin progreso
// conocido, y arco de progreso circular cuando sí hay % (0..1).
// Los puntos animados viven en el part
// indicador_descarga_dots.dart.
// Se conecta con: estado_descarga (EstadoDescarga) + nada más.
// Parte del flujo: búsqueda, feed, detalle, mi espacio (badges).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../core/cache/estado_descarga.dart';

export '../../core/cache/estado_descarga.dart';

part 'indicador_descarga_dots.dart';

/// Punto de estado de descarga reutilizado en toda la app.
class IndicadorDescarga extends StatelessWidget {
  final EstadoDescarga estado;
  final double tamano;
  final double? progreso; // 0.0..1.0, solo cuando estado == enProgreso

  /// Tamaño por defecto del punto de estado en toda la app.
  static const double tamanoPorDefecto = 8;

  const IndicadorDescarga({
    super.key,
    this.estado = EstadoDescarga.ninguno,
    this.tamano = tamanoPorDefecto,
    this.progreso,
  });

  @override
  Widget build(BuildContext context) {
    if (estado == EstadoDescarga.enProgreso) {
      if (progreso != null && progreso! > 0) {
        return _PuntoProgreso(tamano: tamano, color: _color, progreso: progreso!);
      }
      return _PuntoPulsante(tamano: tamano, color: _color);
    }

    final tieneGlow = estado == EstadoDescarga.completado;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
        boxShadow: tieneGlow
            ? [
                BoxShadow(
                  color: _color.withValues(alpha: 0.5),
                  blurRadius: tamano * 1.5,
                  spreadRadius: tamano * 0.3,
                ),
              ]
            : null,
      ),
    );
  }

  Color get _color {
    switch (estado) {
      case EstadoDescarga.completado:
        return const Color(0xFF4CAF50); // verde
      case EstadoDescarga.enProgreso:
        return const Color(0xFFFF9800); // naranja
      case EstadoDescarga.interrumpido:
        return const Color(0xFFE53935); // rojo (error)
      case EstadoDescarga.enCola:
        return const Color(0xFF9E9E9E); // gris medio
      case EstadoDescarga.ninguno:
        return const Color(0xFF808080); // gris
    }
  }
}