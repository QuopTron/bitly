// ─────────────────────────────────────────────────────────────
// slide_gracias_widgets.dart — PART de slide_gracias.dart:
// sub-widgets del slide final (icono con gradiente y glow, loader
// de "completando setup" y countdown circular de 30s con el número
// de segundos restantes). Las funciones reciben el State del slide
// para acceder a sus campos privados.
// Se conecta con: slide_gracias.dart (misma library) + shared.
// Parte del flujo: setup (paso 10: gracias → home).
// ─────────────────────────────────────────────────────────────

part of 'slide_gracias.dart';

Widget _icono(_SlideGraciasState st, Color onBg, Color glowColor) {
  return Container(
    padding: EdgeInsets.all(st.widget.r.spacingM),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        colors: [
          glowColor.withValues(alpha: 0.2),
          glowColor.withValues(alpha: 0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(
        color: glowColor.withValues(alpha: 0.3),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: glowColor.withValues(alpha: 0.15),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Icon(
      Icons.headphones,
      size: st.widget.r.titleSize * 1.4,
      color: glowColor,
    ),
  );
}

Widget _loader(_SlideGraciasState st, Color glowColor) {
  return ContenedorVidrio(
    borderRadius: 14,
    borderColor: glowColor.withValues(alpha: 0.1),
    bgColor: glowColor.withValues(alpha: 0.04),
    padding: EdgeInsets.symmetric(
      horizontal: st.widget.r.spacingXL,
      vertical: st.widget.r.spacingM,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: st.widget.r.footerSize + 4,
          height: st.widget.r.footerSize + 4,
          child: CircularProgressIndicator(strokeWidth: 2, color: glowColor),
        ),
        SizedBox(width: st.widget.r.spacingM),
        Text(
          st.widget.loc.setup.completingSetup,
          style: TextStyle(
            fontSize: st.widget.r.footerSize,
            color: glowColor.withValues(alpha: 0.7),
          ),
        ),
      ],
    ),
  );
}

Widget _countdown(_SlideGraciasState st, Color onBg, Color glowColor) {
  final progreso = st._segundosRestantes / 30;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: st.widget.r.titleSize * 3,
        height: st.widget.r.titleSize * 3,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: st.widget.r.titleSize * 3,
              height: st.widget.r.titleSize * 3,
              child: CircularProgressIndicator(
                value: progreso,
                strokeWidth: 3,
                backgroundColor: onBg.withValues(alpha: 0.06),
                color: glowColor,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${st._segundosRestantes}',
                  style: TextStyle(
                    fontSize: st.widget.r.titleSize + 4,
                    fontWeight: FontWeight.bold,
                    color: glowColor,
                  ),
                ),
                Text(
                  st.widget.loc.setup.secondsAbbrev,
                  style: TextStyle(
                    fontSize: st.widget.r.footerSize,
                    color: onBg.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      SizedBox(height: st.widget.r.spacingS),
      Text(
        st.widget.loc.setup.thankYouStarting,
        style: TextStyle(
          fontSize: st.widget.r.footerSize,
          color: onBg.withValues(alpha: 0.4),
        ),
      ),
    ],
  );
}