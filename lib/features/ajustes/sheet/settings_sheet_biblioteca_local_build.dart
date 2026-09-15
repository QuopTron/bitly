// ─────────────────────────────────────────────────────────────
// settings_sheet_biblioteca_local_build.dart — PART de
// settings_sheet_new.dart: el `build` de la tarjeta "Música local" —
// encabezado, explicación de la indexación por ISRC, botón de
// importar carpeta (con spinner mientras trabaja) y el resumen del
// último import.
// Se conecta con: settings_sheet_new.dart (misma library).
// Parte del flujo: importación local de música del usuario.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

Widget _construirBibliotecaLocal(BuildContext context, Color glowColor, bool importando, String? resumen, VoidCallback importar) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.library_music_rounded,
              color: glowColor,
              size: r.subtitleSize,
            ),
            SizedBox(width: r.spacingS),
            Text(
              'Música local',
              style: TextStyle(
                fontSize: r.subtitleSize,
                fontWeight: FontWeight.w700,
                color: onBg,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          'Importá tu música propia (compras de Amazon, archivos de iTunes Match, '
          'FLAC sueltos). Se indexa por ISRC para que la app la reconozca y no la '
          'vuelva a descargar.',
          style: TextStyle(
            fontSize: r.footerSize - 1,
            color: onBg.withValues(alpha: 0.5),
            height: 1.3,
          ),
        ),
        SizedBox(height: r.spacingS),
        GestureDetector(
          onTap: importando ? null : importar,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: r.spacingM,
              vertical: r.spacingM,
            ),
            decoration: BoxDecoration(
              color: onBg.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: onBg.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (importando)
                  SizedBox(
                    width: r.subtitleSize,
                    height: r.subtitleSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: glowColor,
                    ),
                  )
                else
                  Icon(
                    Icons.create_new_folder_rounded,
                    size: r.subtitleSize + 2,
                    color: glowColor,
                  ),
                SizedBox(width: r.spacingS),
                Text(
                  importando ? 'Importando…' : 'Importar carpeta',
                  style: TextStyle(
                    fontSize: r.subtitleSize,
                    fontWeight: FontWeight.w600,
                    color: onBg.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (resumen != null) ...[
          SizedBox(height: r.spacingXS),
          Text(
            'Importado: $resumen',
            style: TextStyle(
              fontSize: r.footerSize - 1,
              color: glowColor.withValues(alpha: 0.9),
            ),
          ),
        ],
      ],
    );
  
}
