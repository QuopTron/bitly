// ─────────────────────────────────────────────────────────────
// update_sheet_bloques.dart — PART de update_modal.dart: bloques de
// la hoja de actualización — cabecera (ícono, títulos y versión),
// progreso, notas de la release y botones de acción.
// Se conecta con: update_modal.dart (misma library).
// Parte del flujo: Ajustes → Versión → actualización.
// ─────────────────────────────────────────────────────────────

part of 'update_modal.dart';

/// Cabecera de la hoja: ícono circular, título, versión y versión actual.
Widget _cabeceraActualizacion(
  _EstadoHojaActualizacion st,
  Responsive r,
  Color sobreFondo,
  Color apagado,
) {
  final tamano = st._formatearBytes(st.widget.info.apkSize);
  final etiquetaVersion = tamano.isNotEmpty
      ? 'v${st.widget.info.version}  •  $tamano'
      : 'v${st.widget.info.version}';

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: ColoresApp.exito.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          st._descargando ? Icons.downloading_rounded : Icons.system_update,
          size: 28,
          color: ColoresApp.exito,
        ),
      ),
      SizedBox(height: r.spacingL),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
        child: Text(
          st._descargando
              ? 'Descargando actualización...'
              : 'Hay una nueva actualización',
          style: TextStyle(
            fontSize: r.titleSize,
            fontWeight: FontWeight.bold,
            color: sobreFondo,
          ),
          textAlign: TextAlign.center,
        ),
      ),
      SizedBox(height: r.spacingXS),
      Text(
        etiquetaVersion,
        style: TextStyle(
          fontSize: r.subtitleSize,
          color: ColoresApp.exito,
          fontWeight: FontWeight.w600,
        ),
      ),
      SizedBox(height: r.spacingM),
      FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final actual = snapshot.data?.version ?? '...';
          return Text(
            'Versión actual: $actual',
            style: TextStyle(fontSize: r.footerSize, color: apagado),
          );
        },
      ),
      SizedBox(height: r.spacingL),
    ],
  );
}

/// Barra de progreso de la descarga (o texto "Preparando...").
Widget _progresoActualizacion(
  _EstadoHojaActualizacion st,
  Responsive r,
  Color sobreFondo,
  Color apagado,
) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
    child: Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: st._progreso > 0 ? st._progreso : null,
            minHeight: 8,
            backgroundColor: sobreFondo.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(ColoresApp.exito),
          ),
        ),
        SizedBox(height: r.spacingS),
        Text(
          st._progreso > 0
              ? '${(st._progreso * 100).toStringAsFixed(0)}%'
              : 'Preparando...',
          style: TextStyle(fontSize: r.footerSize, color: apagado),
        ),
      ],
    ),
  );
}
