// ─────────────────────────────────────────────────────────────
// settings_sheet_language.dart — PART de settings_sheet_new.dart: el
// SELECTOR de idioma de Ajustes → Apariencia.
//
// Antes la fila de idioma era un interruptor disfrazado de lista: mostraba
// un chevron como si abriera un menú, pero al tocarla saltaba directo al
// otro idioma. Ahora abre esta hoja, lista los idiomas soportados con el
// tilde en el que está puesto, y al elegir uno lo aplica y lo guarda
// (IdiomaHelper). Se cierra sola.
//
// Se conecta con: idioma_helper (aplica y persiste) + mostrar_modal.
// Parte del flujo: Ajustes → Apariencia → Idioma.
// ─────────────────────────────────────────────────────────────

part of '../settings_sheet_new.dart';

/// Abre el selector de idioma. Público: lo llama la pestaña de Apariencia y
/// también las pruebas, que tienen que poder abrir la hoja real.
Future<void> abrirSelectorIdioma(BuildContext context) {
  return mostrarHoja<void>(
    context: context,
    sobreHoja: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _IdiomaSheet(),
  );
}

/// Hoja con los idiomas disponibles, la actual tildada.
class _IdiomaSheet extends StatelessWidget {
  const _IdiomaSheet();

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);
    final bg = ColoresApp.superficie(isDark);
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
            Text(
              t.idiomaSelectorTitulo,
              style: TextStyle(
                fontSize: r.subtitleSize,
                fontWeight: FontWeight.w700,
                color: onBg,
              ),
            ),
            SizedBox(height: r.spacingS),
            for (final idioma in idiomasDisponibles)
              _IdiomaFila(
                key: ValueKey('idioma-${idioma.languageCode}'),
                idioma: idioma,
                nombre: nombreDeIdioma(AppLocalizations.of(context), idioma),
                seleccionado: IdiomaHelper.esActual(context, idioma),
                glowColor:
                    isDark ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio,
                onBg: onBg,
                r: r,
                onTap: () {
                  IdiomaHelper.cambiar(context, idioma);
                  // Se cierra sola: la app se repinta con el locale nuevo.
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}
