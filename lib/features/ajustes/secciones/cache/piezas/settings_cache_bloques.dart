// ─────────────────────────────────────────────────────────────
// settings_cache_bloques.dart — Cabecera de la sección de caché de
// streaming: ícono, título y esqueleto o botón "Limpiar".
// Se conecta con: settings_cache_section.dart (la usa).
// Parte del flujo: Ajustes → Rendimiento/Descargas (caché).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/utilidades/plataforma/responsive.dart';
import '../../../../../shared/widgets/esqueletos/esqueleto_carga.dart';

/// Cabecera de la sección de caché: ícono, título, esqueleto o botón Limpiar.
Widget cacheHeaderRow({
  required BuildContext context,
  required Responsive r,
  required Color onBg,
  required Color glowColor,
  required bool loading,
  required bool clearing,
  required VoidCallback onClear,
}) {
  final c = AppLocalizations.of(context).cache;
  return Row(
    children: [
      Icon(Icons.storage, color: glowColor, size: r.footerSize + 4),
      SizedBox(width: r.spacingS),
      Expanded(
        child: Text(
          c.titulo,
          style: TextStyle(
            fontSize: r.subtitleSize,
            fontWeight: FontWeight.w600,
            color: onBg,
          ),
        ),
      ),
      // Mientras se calcula el tamaño no se pone un circulito: el hueco toma
      // la forma del botón que va a aparecer ahí (mismo alto y esquinas), así
      // la fila no cambia de alto cuando termina de cargar.
      if (loading)
        EsqueletoEtiqueta(
          ancho: r.footerSize * 3 + 30,
          alto: r.footerSize + 9,
          radioBorde: 8,
        ),
      if (!loading)
        GestureDetector(
          onTap: clearing ? null : onClear,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: 4),
            decoration: BoxDecoration(
              color:
                  clearing
                      ? onBg.withValues(alpha: 0.05)
                      : Colors.redAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            // Limpiando: en vez del circulito, una barra con la forma de la
            // etiqueta del botón (que es lo que vuelve cuando termina).
            child:
                clearing
                    ? EsqueletoEtiqueta(
                      ancho: r.footerSize * 3 + 18,
                      alto: r.footerSize + 1,
                      radioBorde: 4,
                    )
                    : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: r.footerSize,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          c.limpiar,
                          style: TextStyle(
                            fontSize: r.footerSize - 1,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
          ),
        ),
    ],
  );
}
