// ─────────────────────────────────────────────────────────────
// slide_gracias_cuerpo.dart — PART de slide_gracias.dart: cuerpo
// del slide final en sus 2 variantes — columna de \"guardando\"
// (loader con mensaje de completado) y columna principal (icono,
// título, mensaje, countdown circular y botón de saltar tras 5s).
// Las funciones reciben el State para acceder a sus campos.
// Se conecta con: slide_gracias.dart (misma library) + shared.
// Parte del flujo: setup (paso 10: gracias → home).
// ─────────────────────────────────────────────────────────────

part of 'slide_gracias.dart';

Widget _cuerpoGuardando(_SlideGraciasState st, Color onBg, Color glowColor) {
  return Padding(
    padding: EdgeInsets.only(bottom: st.widget.r.bottomPadding),
    child: Column(
      children: [
        const Spacer(),
        _icono(st, onBg, glowColor),
        SizedBox(height: st.widget.r.spacingL),
        Text(
          st.widget.loc.setup.thankYouTitle,
          style: TextStyle(
            fontSize: st.widget.r.titleSize + 2,
            fontWeight: FontWeight.bold,
            color: onBg,
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: st.widget.r.spacingM),
        _loader(st, glowColor),
        const Spacer(),
      ],
    ),
  );
}

Widget _cuerpoPrincipal(_SlideGraciasState st, Color onBg, Color glowColor) {
  return Padding(
    padding: EdgeInsets.only(bottom: st.widget.r.bottomPadding),
    child: Column(
      children: [
        const Spacer(),
        _icono(st, onBg, glowColor),
        SizedBox(height: st.widget.r.spacingL),
        Text(
          st.widget.loc.setup.thankYouTitle,
          style: TextStyle(
            fontSize: st.widget.r.titleSize + 2,
            fontWeight: FontWeight.bold,
            color: onBg,
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: st.widget.r.spacingS),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: st.widget.r.spacingXL),
          child: Text(
            st.widget.loc.setup.thankYouMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: st.widget.r.footerSize,
              color: onBg.withValues(alpha: 0.5),
            ),
          ),
        ),
        SizedBox(height: st.widget.r.spacingXL),
        _countdown(st, onBg, glowColor),
        const Spacer(),
        if (st._mostrarSaltar)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: st.widget.r.spacingXL),
            child: BotonVidrio(
              label: st.widget.loc.setup.thankYouSkip,
              onPressed: st._irAHome,
              height: st.widget.r.continueButtonHeight,
              accent: glowColor,
            ),
          ),
        SizedBox(height: st.widget.r.spacingM),
      ],
    ),
  );
}