// ─────────────────────────────────────────────────────────────
// update_sheet_ui.dart — PART de update_modal.dart: UI de la hoja
// de actualización (handle, icono, versión, progreso, notas y
// botones). Se expone como función top-level y el State delega su
// build acá para mantener el archivo principal bajo el límite de
// líneas.
// Se conecta con: update_modal.dart (misma library).
// Parte del flujo: Ajustes → Versión → actualización.
// ─────────────────────────────────────────────────────────────

part of 'update_modal.dart';

/// Construye la hoja de actualización a partir del estado [_EstadoHojaActualizacion].
Widget _construirHojaActualizacion(
  _EstadoHojaActualizacion st,
  BuildContext context,
) {
  final info = st.widget.info;
  final r = Responsive(context);
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  final fondo = ColoresApp.superficie(esOscuro);
  final sobreFondo = ColoresApp.enSuperficie(esOscuro);
  final apagado = ColoresApp.enSuperficieApagado(esOscuro);
  final borde = ColoresApp.borde(esOscuro);

  final tamano = st._formatearBytes(info.apkSize);
  final etiquetaVersion =
      tamano.isNotEmpty ? 'v${info.version}  •  $tamano' : 'v${info.version}';

  return Container(
    margin: EdgeInsets.only(top: r.spacingXL * 2),
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: r.spacingM),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: sobreFondo.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: r.spacingXL),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: ColoresApp.exito.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                st._descargando
                    ? Icons.downloading_rounded
                    : Icons.system_update,
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
            if (st._descargando)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: st._progreso > 0 ? st._progreso : null,
                        minHeight: 8,
                        backgroundColor: sobreFondo.withValues(alpha: 0.08),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(ColoresApp.exito),
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
              ),
            if (st._error != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
                child: Text(
                  st._error!,
                  style: TextStyle(
                    fontSize: r.footerSize,
                    color: ColoresApp.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (!st._descargando && info.body.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(r.spacingM),
                  decoration: BoxDecoration(
                    color: sobreFondo.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borde),
                  ),
                  child: Text(
                    info.body,
                    style: TextStyle(
                      fontSize: r.footerSize,
                      color: sobreFondo.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            SizedBox(height: r.spacingXL),
            if (!st._descargando)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: st._descargarEInstalar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColoresApp.exito,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download_rounded, size: 20),
                        SizedBox(width: r.spacingS),
                        Text(
                          'Descargar e instalar',
                          style: TextStyle(
                            fontSize: r.subtitleSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (!st._descargando)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  r.spacingXL,
                  r.spacingS,
                  r.spacingXL,
                  r.spacingXL,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: apagado,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Ahora no',
                      style: TextStyle(
                        fontSize: r.footerSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            SizedBox(height: r.spacingM),
          ],
        ),
      ),
    ),
  );
}
