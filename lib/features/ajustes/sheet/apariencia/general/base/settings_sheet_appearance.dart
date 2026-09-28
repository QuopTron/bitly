// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance.dart — PART de settings_sheet_new.dart: pestaña Apariencia — selector de
// tema (Oscuro/Claro) y de estilo visual (Clásico/Spotify) con
// controles granulares por componente.
// Se conecta con: settings_sheet_new.dart (misma library) + tema.
// Parte del flujo: Ajustes → Apariencia.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// Pickers del tab Apariencia: selector de tema (Oscuro/Claro) con dos
/// tiles grandes, selector de estilo visual (Clásico/Spotify) con
/// controles granulares por componente, y la sección de idioma.
class _AppearanceTab extends StatelessWidget {
  final bool isDark;
  final Color glowColor;
  final ValueChanged<bool> onThemeChanged;

  const _AppearanceTab({
    required this.isDark,
    required this.glowColor,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);
    final loc = AppLocalizations.of(context);

    // Los ajustes de Apariencia se GIRAN, uno por pantalla: apilados eran ocho
    // tarjetas seguidas y para llegar al idioma había que bajar toda la pestaña.
    return CarruselAjustes(
      key: const ValueKey('carrusel-apariencia'),
      etiqueta: loc.ajustes.apariencia,
      glowColor: glowColor,
      onBg: onBg,
      r: r,
      paginas: [
        // ── Tema (Oscuro / Claro) ──
        _ThemePicker(
          isDark: isDark,
          glowColor: glowColor,
          onBg: onBg,
          r: r,
          loc: loc,
          onThemeChanged: onThemeChanged,
        ),
        // ── Estilo con cover — un control, de Normal a Spotify ──
        _StylePicker(glowColor: glowColor, onBg: onBg, r: r, loc: loc),
        // ── Barras (esquinas de arriba del navbar/miniplayer + cofre +
        //    tamaño y forma del miniplayer) ──
        _BarrasCard(
          key: const ValueKey('ajustes-barras'),
          glowColor: glowColor,
          onBg: onBg,
          r: r,
          loc: loc,
        ),
        // ── Tipografía: con qué letra se escribe toda la app ──
        // Las tarjetas llevan clave: comparten textos ("Tipografía", "Heredar")
        // y sin ella no habría forma de apuntar a una desde una prueba o desde
        // el tutorial interactivo.
        _FuentesCard(
          key: const ValueKey('ajustes-tipografia'),
          glowColor: glowColor,
          onBg: onBg,
          r: r,
          loc: loc,
        ),
        // ── Diseño por vista: cada pantalla con su propia letra, color y aire ──
        _VistasCard(
          key: const ValueKey('ajustes-vistas'),
          glowColor: glowColor,
          onBg: onBg,
          r: r,
          loc: loc,
        ),
        // ── Diseño personalizable (separación y redondeo de las cards) ──
        _DisenoCard(glowColor: glowColor, onBg: onBg, r: r, loc: loc),
        // ── Acciones rápidas: qué hace cada gesto sobre una canción ──
        TarjetaAccionesRapidas(glowColor: glowColor, onBg: onBg, r: r),
        // ── Idioma ──
        SettingsLanguageSection(
          onBg: onBg,
          glowColor: glowColor,
          loc: loc,
          // Abre el selector: el idioma lo aplica y lo guarda la hoja misma
          // (IdiomaHelper), y el notifier repinta la app con el locale nuevo.
          onTap: () => abrirSelectorIdioma(context),
        ),
      ],
    );
  }
}
