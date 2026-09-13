// ─────────────────────────────────────────────────────────────
// slide_usuario_widgets.dart — PART de slide_usuario.dart:
// sub-widgets del slide de usuario (icono circular, banner de
// nombre previo cuando hay cuenta existente y fila de botones
// atrás/siguiente). Las funciones reciben el widget SlideUsuario
// para acceder a sus campos (state, loc, r).
// Se conecta con: slide_usuario.dart (misma library) + shared
// (vidrio, botón) + setup_bloc.
// Parte del flujo: setup (paso 3: nombre de usuario).
// ─────────────────────────────────────────────────────────────

part of 'slide_usuario.dart';

Widget _icono(SlideUsuario w, Color onBg) {
  return Container(
    padding: EdgeInsets.all(w.r.spacingS),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: onBg.withValues(alpha: 0.04),
      border: Border.all(color: onBg.withValues(alpha: 0.08), width: 0.8),
    ),
    child: Icon(
      Icons.person_outline,
      size: w.r.titleSize * 1.1,
      color: onBg.withValues(alpha: 0.55),
    ),
  );
}

Widget _bannerExistente(SlideUsuario w, Color onBg, Color glowColor) {
  return ContenedorVidrio(
    borderRadius: 12,
    borderColor: glowColor.withValues(alpha: 0.2),
    bgColor: glowColor.withValues(alpha: 0.06),
    padding: EdgeInsets.symmetric(horizontal: w.r.spacingM, vertical: w.r.spacingS),
    child: Row(
      children: [
        Icon(Icons.info_outline, color: glowColor, size: w.r.footerSize + 2),
        SizedBox(width: w.r.spacingS),
        Expanded(
          child: Text(
            '${w.loc.setup.previousNameWas} "${w.state.usuarioExistente}"',
            style: TextStyle(fontSize: w.r.footerSize, color: glowColor),
          ),
        ),
      ],
    ),
  );
}

Widget _botones(BuildContext context, SlideUsuario w, Color glowColor) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: w.r.spacingXL),
    child: SizedBox(
      height: w.r.continueButtonHeight,
      child: Row(
        children: [
          Expanded(
            child: BotonVidrio(
              label: w.loc.setup.back,
              onPressed: () =>
                  context.read<SetupBloc>().add(const PasoAnterior()),
              height: w.r.continueButtonHeight,
              accent: glowColor,
            ),
          ),
          SizedBox(width: w.r.spacingM),
          Expanded(
            child: BotonVidrio(
              label: w.loc.setup.next,
              onPressed: w.state.usuario.trim().isNotEmpty
                  ? () => context.read<SetupBloc>().add(const SiguientePaso())
                  : null,
              height: w.r.continueButtonHeight,
              accent: glowColor,
            ),
          ),
        ],
      ),
    ),
  );
}