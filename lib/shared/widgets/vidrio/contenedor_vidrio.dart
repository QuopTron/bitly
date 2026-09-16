// ─────────────────────────────────────────────────────────────
// contenedor_vidrio.dart — Contenedor glassmorphism con blur real
// opcional (BackdropFilter) y gradiente opcional. Todos los
// parámetros nuevos son opt-in para que los llamadores existentes
// sigan igual (sin blur ni gradiente por defecto).
//
// Adaptativo: el blur se delega a DesenfoqueAdaptativo y el glow se omite
// cuando el perfil de rendimiento dice que no hay efectos pesados. Así las
// 40+ superficies de vidrio de la app son gratis en un equipo de gama baja
// (el desenfoque a pantalla completa es justo lo que congela las GPU
// modestas tipo PowerVR de un Helio G) sin tocar ningún llamador.
//
// Se conecta con: todas las vistas y widgets (superficies glass) +
// efectos_app (interruptor global de efectos) + desenfoque_adaptativo.
// Parte del flujo: presentación (superficies y tarjetas).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../utilidades/plataforma/efectos_app.dart';
import 'desenfoque_adaptativo.dart';

/// Contenedor glassmorphism con blur/gradiente/glow opcionales.
class ContenedorVidrio extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? bgColor;

  /// Cuando no es null aplica un desenfoque de fondo con este sigma.
  /// Valores típicos: 12–24. null (default) desactiva el blur.
  final double? blurSigma;

  /// Gradiente opcional renderizado sobre [bgColor] (p.ej. tintes diagonales).
  final Gradient? gradient;

  /// Cuando es true renderiza un glow exterior suave usando [borderColor].
  final bool glowBorder;

  /// Radio de expansión del glow cuando [glowBorder] es true. Default 4.
  final double glowSpread;

  /// Radio de blur del glow cuando [glowBorder] es true. Default 12.
  final double glowBlur;

  const ContenedorVidrio({
    super.key,
    required this.child,
    this.borderRadius = 14,
    this.borderColor,
    this.borderWidth = 0.8,
    this.margin,
    this.padding,
    this.bgColor,
    this.blurSigma,
    this.gradient,
    this.glowBorder = false,
    this.glowSpread = 4,
    this.glowBlur = 12,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius;
    final border = borderColor ?? Colors.transparent;
    final sinEfectos = !EfectosApp.permitirDesenfoque.value;

    // ── Sombra del glow ── (se omite en gama baja: una sombra con blur alto
    // por tarjeta se paga caro al desplazar listas largas).
    final sombras = (glowBorder && !sinEfectos)
        ? [
            BoxShadow(
              color: border.withValues(alpha: 0.18),
              blurRadius: glowBlur,
              spreadRadius: glowSpread,
            ),
          ]
        : null;

    final contenido = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: bgColor ?? Colors.transparent,
        gradient: gradient,
        border: Border.all(color: border, width: borderWidth),
        boxShadow: sombras,
      ),
      child: child,
    );

    // El desenfoque pasa por DesenfoqueAdaptativo: en gama baja se apaga solo.
    Widget interno = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: blurSigma != null
          ? DesenfoqueAdaptativo(sigma: blurSigma!, child: contenido)
          : contenido,
    );

    if (margin != null) {
      interno = Padding(padding: margin!, child: interno);
    }

    return interno;
  }
}
