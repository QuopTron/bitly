// ─────────────────────────────────────────────────────────────
// settings_sheet_body_state.dart — PART de settings_sheet_new.dart:
// _SettingsSheetBodyState, el cuerpo de la hoja de Ajustes: drag handle,
// perfil compacto, navegación (riel o burbujas) y el contenido.
//
// En pantalla ancha el navegador va a la IZQUIERDA del contenido (riel),
// así las 7 pestañas entran con su nombre completo y el contenido no se
// aprieta; en celular quedan las burbujas arriba.
//
// Se conecta con: settings_sheet_nav.dart (navegación) +
// settings_sheet_sheet_widgets.dart (contenido).
// Parte del flujo: Ajustes (cuerpo de la hoja).
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

class _SettingsSheetBodyState extends State<_SettingsSheetBody> {
  @override
  Widget build(BuildContext context) {
    // Declarado con su tipo para que se vea que la hoja mide por APARATO: en
    // la tele todo esto crece (ver responsive.dart).
    final Responsive r = widget.r;
    final esp = EspecificacionesPlataforma.de(context);
    final isDark = widget.isDark;
    final onBg = widget.onBg;
    final bg = widget.bg;
    final hasTrack = widget.hasTrack;
    final ancho = ajustesUsaRiel(context);
    // Tirador de la hoja: en celular queda igual (4 de alto) y en la tele se
    // agranda junto con la hoja.
    final altoTirador = r.spacingXS;

    final nav = _NavAjustes(
      currentIndex: widget.selectedTab,
      glowColor: widget.glowColor,
      onBg: onBg,
      r: r,
      onTap: widget.onTabTap,
    );

    // Contenido: perfil/estadísticas cuando no hay pestaña elegida, o los
    // tabs. La key es el objetivo de los pasos que explican cada pestaña
    // (el contenido cambia con la pestaña que el tutorial va pidiendo).
    final contenido = KeyedSubtree(
      key: keyTutorialAjustesContenido,
      child: _SettingsTabs(
        controller: widget.tabController,
        selectedTab: widget.selectedTab,
        isDark: isDark,
        glowColor: widget.glowColor,
        onBg: onBg,
        r: r,
        premium: widget.premium,
        likedCount: widget.likedCount,
        downloadedCount: widget.downloadedCount,
        onThemeChanged: widget.onThemeChanged,
        onPremiumChanged: widget.onPremiumChanged,
      ),
    );

    // Objetivo del tutorial para el paso que explica las pestañas.
    final navegacion = KeyedSubtree(key: keyTutorialAjustesTabs, child: nav);

    Widget sheet = Container(
      // Más alto que la mitad: deja ~20% visible arriba (contexto de la
      // página) y le da más aire al contenido de cada pestaña.
      height: MediaQuery.of(context).size.height * 0.8,
      margin: EdgeInsets.only(top: r.spacingXL),
      decoration: BoxDecoration(
        // Transparent when a track is playing: the _SongTintedBackground
        // provides the blurred cover + veil underneath.
        color: hasTrack ? Colors.transparent : bg,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(esp.radioHoja),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(esp.radioHoja),
        ),
        child: Column(
          children: [
            SizedBox(height: r.spacingM),
            // Drag handle
            Container(
              width: r.sobre(40, 64),
              height: altoTirador,
              decoration: BoxDecoration(
                color: onBg.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(altoTirador / 2),
              ),
            ),
            SizedBox(height: r.spacingM),
            // Compact profile header (always visible)
            _ProfileHeader(
              username: widget.username,
              glowColor: widget.glowColor,
              likedCount: widget.likedCount,
              downloadedCount: widget.downloadedCount,
              premium: widget.premium,
            ),
            SizedBox(height: r.spacingM),
            Expanded(
              // El menú de navegación del celular (3 teclas) tapa el borde
              // físico: la hoja se ancla ahí, así que reservamos su alto para
              // que el último botón de cada pestaña nunca quede debajo.
              child: Padding(
                padding: EdgeInsets.only(bottom: insetInferiorSistema(context)),
                child:
                    ancho
                        ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [navegacion, Expanded(child: contenido)],
                        )
                        : Column(
                          children: [
                            navegacion,
                            SizedBox(height: r.spacingS),
                            Expanded(child: contenido),
                          ],
                        ),
              ),
            ),
          ],
        ),
      ),
    );

    if (hasTrack) {
      sheet = ClipRRect(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(esp.radioHoja),
        ),
        child: DesenfoqueAdaptativo(
          sigma: sl<ValueNotifier<PerfilRendimiento>>().value.sigmaDesenfoque,
          child: sheet,
        ),
      );
    }
    return sheet;
  }
}
