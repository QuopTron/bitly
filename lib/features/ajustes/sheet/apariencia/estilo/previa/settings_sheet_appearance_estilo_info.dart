// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_estilo_info.dart — PART de
// settings_sheet_new.dart: la hoja que explica qué hace la OPACIDAD
// del estilo con cover (el botón "i" del encabezado del bloque).
//
// Por qué existe: el control cambia la app entera, así que "Opacidad"
// sola no alcanza para que se entienda qué se está moviendo. Acá se
// cuenta de dónde a dónde va, qué son los paneles de la vista previa
// y para qué sirve "Personalizado".
//
// Abre con `sobreHoja: true`: saltando desde el sheet de Ajustes, el
// velo queda opaco y no se ve un modal sobre otro.
//
// Se conecta con: mostrar_modal + colores_app + strings_apariencia_estilo.
// Parte del flujo: Ajustes → Apariencia → Estilo con cover → "i".
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// Abre la explicación del control de opacidad.
Future<void> abrirInfoEstilo(BuildContext context) {
  return mostrarHoja<void>(
    context: context,
    sobreHoja: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _InfoEstiloSheet(),
  );
}

/// Hoja con la explicación del control de opacidad.
class _InfoEstiloSheet extends StatelessWidget {
  const _InfoEstiloSheet();

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);
    final bg = ColoresApp.superficie(isDark);
    final glow = isDark ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
    final t = AppLocalizations.of(context).aparienciaEstilo;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: r.spacingL,
          right: r.spacingL,
          bottom: r.spacingL + insetInferiorSistema(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: r.spacingM),
            // Manija de la hoja.
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: onBg.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: r.spacingM),
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: glow,
                  size: r.subtitleSize,
                ),
                SizedBox(width: r.spacingS),
                Expanded(
                  child: Text(
                    t.estiloInfoTitulo,
                    style: TextStyle(
                      fontSize: r.subtitleSize,
                      fontWeight: FontWeight.w700,
                      color: onBg,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: r.spacingS),
            // La explicación, con scroll por si el idioma la hace más larga.
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  t.estiloInfoTexto,
                  style: TextStyle(
                    fontSize: r.footerSize,
                    height: 1.45,
                    color: onBg.withValues(alpha: 0.72),
                  ),
                ),
              ),
            ),
            SizedBox(height: r.spacingM),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: glow,
                  foregroundColor: ColoresApp.superficie(isDark),
                ),
                child: Text(t.estiloInfoCerrar),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
