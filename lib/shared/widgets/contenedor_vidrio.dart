// ─────────────────────────────────────────────────────────────
// contenedor_vidrio.dart — Contenedor glassmorphism moderno con
// blur real opcional (BackdropFilter) y gradiente opcional. Todos
// los parámetros nuevos son opt-in para que los llamadores
// existentes sigan igual (sin blur ni gradiente por defecto).
// Se conecta con: todas las vistas y widgets (superficies glass).
// Parte del flujo: presentación (superficies y tarjetas).
// ─────────────────────────────────────────────────────────────

import 'dart:ui';

import 'package:flutter/material.dart';

/// Contenedor glassmorphism con blur/gradiente/glow opcionales.
class ContenedorVidrio extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? bgColor;

  /// Cuando no es null aplica un [BackdropFilter] con este sigma de blur.
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

    // ── Sombra del glow ──
    final sombras = glowBorder
        ? [
            BoxShadow(
              color: border.withValues(alpha: 0.18),
              blurRadius: glowBlur,
              spreadRadius: glowSpread,
            ),
          ]
        : null;

    // Sin BackdropFilter cuando no hay blur — ahorra compositing de GPU
    // en los 40+ lugares donde se usa este contenedor.
    Widget contenido = Container(
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

    Widget interno = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: blurSigma != null
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma!, sigmaY: blurSigma!),
              child: contenido,
            )
          : contenido,
    );

    if (margin != null) {
      interno = Padding(padding: margin!, child: interno);
    }

    return interno;
  }
}