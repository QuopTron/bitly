// ─────────────────────────────────────────────────────────────
// desenfoque_adaptativo.dart — Envoltorio de desenfoque que se APAGA solo
// en equipos de gama baja.
//
// Por qué existe: un `BackdropFilter` desenfoca TODO lo que hay detrás en cada
// frame. En un celular con GPU modesta (PowerVR/Mali de gama baja) eso es lo
// que congela la app. Todos los widgets que quieren vidrio usan este envoltorio
// en vez de `BackdropFilter` directo: si el perfil de rendimiento dice que no
// hay efectos pesados, devuelve el hijo intacto (sin capa extra de GPU) y el
// resultado se ve igual porque el fondo del vidrio es opaco/semitransparente.
//
// Se conecta con: efectos_app (el interruptor) y contenedor_vidrio.
// Parte del flujo: presentación (superficies de vidrio).
// ─────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../utilidades/plataforma/efectos_app.dart';

/// Aplica un desenfoque de fondo de [sigma] px… salvo que el equipo no lo
/// soporte, en cuyo caso devuelve [child] tal cual.
class DesenfoqueAdaptativo extends StatelessWidget {
  final double sigma;
  final Widget child;

  const DesenfoqueAdaptativo({
    super.key,
    required this.sigma,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!EfectosApp.permitirDesenfoque.value) return child;

    // Nunca por encima del tope del perfil: el coste crece con el radio.
    final efectivo = math.min(sigma, EfectosApp.sigmaMaximo.value);
    if (efectivo <= 0) return child;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: efectivo, sigmaY: efectivo),
      child: child,
    );
  }
}

/// Desenfoca al HIJO (no lo que hay detrás): el cover difuminado de las
/// cabeceras, hojas y del reproductor.
///
/// Misma regla que [DesenfoqueAdaptativo]: en gama baja devuelve el hijo tal
/// cual, porque un `ImageFiltered` a pantalla completa (o por tarjeta de
/// grilla) se recompone en cada frame y es lo que congela las GPU modestas.
class DesenfoqueHijo extends StatelessWidget {
  final double sigma;
  final Widget child;

  const DesenfoqueHijo({super.key, required this.sigma, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!EfectosApp.permitirDesenfoque.value) return child;
    final efectivo = math.min(sigma, EfectosApp.sigmaMaximo.value);
    if (efectivo <= 0) return child;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: efectivo, sigmaY: efectivo),
      child: child,
    );
  }
}
