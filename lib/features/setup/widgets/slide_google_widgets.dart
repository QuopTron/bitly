// ─────────────────────────────────────────────────────────────
// slide_google_widgets.dart — PART de slide_google.dart: sub-widgets
// del slide de Google (insignia con el logo, tarjeta de información
// con las razones para conectar, botón de iniciar sesión, chip de
// "conectado" y botones atrás/siguiente). Las funciones reciben el
// State del slide para acceder a sus campos privados (_t,
// _conectando, widget).
// Se conecta con: slide_google.dart (misma library) + shared
// (vidrio, botón, logo_google) + setup_bloc.
// Parte del flujo: setup (paso 4: conexión con Google).
// ─────────────────────────────────────────────────────────────

part of 'slide_google.dart';

Widget _insigniaGoogle() {
  // Logo real de Google (tile blanco mantiene los 4 colores en claro/oscuro).
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: const LogoGoogle(tamano: 52),
  );
}

Widget _botonConectar(_SlideGoogleState st, Color glowColor) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: st.widget.r.spacingXL),
    child: SizedBox(
      height: st.widget.r.continueButtonHeight,
      width: double.infinity,
      child: BotonVidrio(
        label: st._conectando
            ? st._t('Conectando…', 'Connecting…')
            : st._t('Iniciar sesión con Google', 'Sign in with Google'),
        onPressed: st._conectando ? null : () => st._conectar(st.context),
        height: st.widget.r.continueButtonHeight,
        accent: glowColor,
        icon: st._conectando
            ? const Icon(Icons.hourglass_top, size: 22)
            : const LogoGoogle(tamano: 20),
      ),
    ),
  );
}

Widget _chipConectado(_SlideGoogleState st, Color glowColor) {
  return ContenedorVidrio(
    borderRadius: 10,
    borderColor: glowColor.withValues(alpha: 0.35),
    bgColor: glowColor.withValues(alpha: 0.08),
    padding: EdgeInsets.symmetric(
      horizontal: st.widget.r.spacingM,
      vertical: st.widget.r.spacingS,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle,
          color: glowColor,
          size: st.widget.r.subtitleSize,
        ),
        SizedBox(width: st.widget.r.spacingS),
        Text(
          st._t('Conectado con Google', 'Connected with Google'),
          style: TextStyle(
            fontSize: st.widget.r.footerSize + 1,
            fontWeight: FontWeight.w600,
            color: glowColor,
          ),
        ),
      ],
    ),
  );
}

Widget _botones(_SlideGoogleState st, BuildContext context, Color glowColor) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: st.widget.r.spacingXL),
    child: SizedBox(
      height: st.widget.r.continueButtonHeight,
      child: Row(
        children: [
          Expanded(
            child: BotonVidrio(
              label: st.widget.loc.setup.back,
              onPressed: () =>
                  context.read<SetupBloc>().add(const PasoAnterior()),
              height: st.widget.r.continueButtonHeight,
              accent: glowColor,
            ),
          ),
          SizedBox(width: st.widget.r.spacingM),
          Expanded(
            child: BotonVidrio(
              label: st.widget.loc.setup.next,
              onPressed: () =>
                  context.read<SetupBloc>().add(const SiguientePaso()),
              height: st.widget.r.continueButtonHeight,
              accent: glowColor,
            ),
          ),
        ],
      ),
    ),
  );
}