// ─────────────────────────────────────────────────────────────
// settings_cache_bloques.dart — Cabecera de la sección de caché de
// streaming: ícono, título y spinner o botón "Limpiar".
// Se conecta con: settings_cache_section.dart (la usa).
// Parte del flujo: Ajustes → Rendimiento/Descargas (caché).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../shared/utilidades/plataforma/responsive.dart';

/// Cabecera de la sección de caché: ícono, título, spinner o botón Limpiar.
Widget cacheHeaderRow({
  required Responsive r,
  required Color onBg,
  required Color glowColor,
  required bool loading,
  required bool clearing,
  required VoidCallback onClear,
}) {
  return Row(children: [
    Icon(Icons.storage, color: glowColor, size: r.footerSize + 4),
    SizedBox(width: r.spacingS),
    Expanded(
      child: Text(
        'Caché de streaming',
        style: TextStyle(
          fontSize: r.subtitleSize,
          fontWeight: FontWeight.w600,
          color: onBg,
        ),
      ),
    ),
    if (loading)
      SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: onBg.withValues(alpha: 0.3),
        ),
      ),
    if (!loading)
      GestureDetector(
        onTap: clearing ? null : onClear,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: 4),
          decoration: BoxDecoration(
            color: clearing
                ? onBg.withValues(alpha: 0.05)
                : Colors.redAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: clearing
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: onBg.withValues(alpha: 0.4),
                  ),
                )
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.delete_outline,
                      size: r.footerSize, color: Colors.redAccent),
                  const SizedBox(width: 3),
                  Text(
                    'Limpiar',
                    style: TextStyle(
                      fontSize: r.footerSize - 1,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ]),
        ),
      ),
  ]);
}
