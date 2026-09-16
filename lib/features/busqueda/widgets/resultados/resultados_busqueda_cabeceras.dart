// ─────────────────────────────────────────────────────────────
// resultados_busqueda_cabeceras.dart — PART de
// resultados_busqueda.dart: las cabeceras de los resultados (por
// categoría y por fuente) con icono, nombre y contador.
//
// Se conecta con: resultados_busqueda.dart (misma library).
// Parte del flujo: búsqueda (resultados agrupados).
// ─────────────────────────────────────────────────────────────

part of 'resultados_busqueda.dart';

/// Cabecera de sección por categoría (icono + nombre + count).
Widget _cabeceraSeccion(
  BuildContext context,
  String cat,
  int count,
  Responsive r,
  Color colorBrillo,
  Color onBg,
) {
  return Padding(
    // Simétrico y alineado con la portada de la tarjeta (margen + padding).
    padding: EdgeInsets.fromLTRB(
      r.spacingS * 2,
      r.spacingM,
      r.spacingS * 2,
      r.spacingS,
    ),
    child: Row(
      children: [
        Icon(
          _iconoPorCategoria[cat] ?? Icons.search,
          size: 18,
          color: onBg.withValues(alpha: 0.6),
        ),
        SizedBox(width: r.spacingS),
        Text(
          _etiquetaCategoria(AppLocalizations.of(context), cat),
          style: TextStyle(
            fontSize: r.subtitleSize + 4,
            fontWeight: FontWeight.bold,
            color: onBg,
          ),
        ),
        SizedBox(width: r.spacingXS),
        Text(
          '($count)',
          style: TextStyle(
            fontSize: r.footerSize + 1,
            color: onBg.withValues(alpha: 0.4),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

/// Cabecera de sección por fuente (icono de la extensión + count).
Widget _cabeceraFuente(
  BuildContext context,
  String fuente,
  int count,
  Responsive r,
  Color colorBrillo,
  Color onBg,
) {
  return Padding(
    // Simétrico y alineado con la portada de la tarjeta (margen + padding).
    padding: EdgeInsets.fromLTRB(
      r.spacingS * 2,
      r.spacingM,
      r.spacingS * 2,
      r.spacingS,
    ),
    child: Row(
      children: [
        Icon(
          iconosFuente[fuente] ?? Icons.cloud_outlined,
          size: 18,
          color: onBg.withValues(alpha: 0.6),
        ),
        SizedBox(width: r.spacingS),
        Text(
          nombreFuente(fuente),
          style: TextStyle(
            fontSize: r.subtitleSize + 4,
            fontWeight: FontWeight.bold,
            color: onBg,
          ),
        ),
        SizedBox(width: r.spacingXS),
        Text(
          '($count)',
          style: TextStyle(
            fontSize: r.footerSize + 1,
            color: onBg.withValues(alpha: 0.4),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
