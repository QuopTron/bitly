// ─────────────────────────────────────────────────────────────
// boton_vidrio.dart — Botón glassmorphism global: ancho completo,
// alto configurable, con icono/label opcionales, estado de carga
// (spinner) y color de acento. Centraliza el estilo de botones de
// la app para no repetir ElevatedButton.styleFrom en cada vista.
// Se conecta con: todas las vistas y widgets con acciones.
// Parte del flujo: presentación (botones).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../tema/colores_app.dart';

/// Botón glass de ancho completo con estado de carga.
class BotonVidrio extends StatelessWidget {
  final String? label;
  final Widget? icon;
  final Widget? customChild;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;
  final double borderRadius;
  final Color accent;

  const BotonVidrio({
    super.key,
    this.label,
    this.icon,
    this.customChild,
    required this.onPressed,
    this.isLoading = false,
    this.height = 38,
    this.borderRadius = 22,
    this.accent = ColoresApp.primario,
  });

  @override
  Widget build(BuildContext context) {
    final habilitado = onPressed != null && !isLoading;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent.withValues(alpha: habilitado ? 0.15 : 0.04),
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: BorderSide(
              color: accent.withValues(alpha: habilitado ? 0.4 : 0.08),
              width: 1,
            ),
          ),
        ),
        onPressed: onPressed,
        child: customChild ?? _contenido(accent, habilitado),
      ),
    );
  }

  Widget _contenido(Color accent, bool habilitado) {
    if (isLoading) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: accent.withValues(alpha: 0.7),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: 6)],
        if (label != null)
          Text(
            label!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accent.withValues(alpha: habilitado ? 1 : 0.35),
            ),
          ),
      ],
    );
  }
}