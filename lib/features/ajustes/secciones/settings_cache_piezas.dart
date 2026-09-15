// ─────────────────────────────────────────────────────────────
// settings_cache_piezas.dart — Piezas visuales y helpers de la
// sección de caché de streaming: fila de estadística, selector de
// límite en MB, opciones de tamaño y formateo de bytes/nivel.
// Se conecta con: settings_cache_section.dart (las usa).
// Parte del flujo: Ajustes → Rendimiento/Descargas (caché).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../shared/utilidades/plataforma/responsive.dart';

/// Fila de una estadística de caché (ícono + valor + etiqueta).
Widget statRowCache(
  IconData icon,
  String value,
  String label,
  Color onBg,
  Responsive r,
) {
  return Row(children: [
    Icon(icon, size: r.footerSize - 2, color: onBg.withValues(alpha: 0.5)),
    SizedBox(width: r.spacingS),
    Expanded(
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: r.footerSize - 1,
            color: onBg.withValues(alpha: 0.8),
          ),
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: '  •  $label',
              style: TextStyle(color: onBg.withValues(alpha: 0.4)),
            ),
          ],
        ),
      ),
    ),
  ]);
}
