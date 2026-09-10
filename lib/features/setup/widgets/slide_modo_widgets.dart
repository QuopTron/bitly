// ─────────────────────────────────────────────────────────────
// slide_modo_widgets.dart — PART de slide_modo.dart: sub-widgets
// del slide de modo (icono circular, aviso de trial expirado,
// tarjetas Free/Premium y fila de botones atrás/siguiente). Las
// funciones reciben el widget SlideModo para acceder a sus campos
// (state, loc, r, isDark, showInfo).
// Se conecta con: slide_modo.dart (misma library) + shared
// (tarjeta_modo, vidrio, botón) + setup_bloc.
// Parte del flujo: setup (paso 5: modo de uso).
// ─────────────────────────────────────────────────────────────

part of 'slide_modo.dart';

Widget _icono(SlideModo w, Color onBg) => Container(
  padding: EdgeInsets.all(w.r.spacingS),
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: onBg.withValues(alpha: 0.04),
    border: Border.all(color: onBg.withValues(alpha: 0.08), width: 0.8),
  ),
  child: Icon(
    Icons.app_settings_alt,
    size: w.r.titleSize * 1.1,
    color: onBg.withValues(alpha: 0.55),
  ),
);

Widget _avisoTrial(SlideModo w, Color onBg, Color glowColor) => Padding(
  padding: EdgeInsets.symmetric(horizontal: w.r.spacingXL),
  child: ContenedorVidrio(
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
            w.loc.setup.trialExpired,
            style: TextStyle(fontSize: w.r.footerSize, color: glowColor),
          ),
        ),
      ],
    ),
  ),
);

Widget _tarjetaFree(BuildContext context, SlideModo w, Color glowColor) =>
    TarjetaModo(
      title: w.loc.setup.free,
      subtitle: w.loc.setup.freeInfo,
      icon: Icons.music_note,
      iconColor: ColoresApp.verdeBrillante,
      selected: w.state.modoSeleccionado == 'free',
      onTap: () => context.read<SetupBloc>().add(const SeleccionarModo('free')),
      onInfoTap: () => w.showInfo(w.loc.setup.free, w.loc.setup.freeDetailedInfo),
      glowColor: glowColor,
    );

Widget _tarjetaPremium(BuildContext context, SlideModo w, Color glowColor) =>
    TarjetaModo(
      title: w.loc.setup.premium,
      subtitle: w.loc.setup.premiumInfo,
      icon: Icons.verified,
      iconColor: glowColor,
      selected: w.state.modoSeleccionado == 'premium',
      onTap: () =>
          context.read<SetupBloc>().add(const SeleccionarModo('premium')),
      onInfoTap: () =>
          w.showInfo(w.loc.setup.premium, w.loc.setup.premiumDetailedInfo),
      glowColor: glowColor,
    );

Widget _botones(BuildContext context, SlideModo w, Color glowColor) {
  final nextOk = w.state.modoSeleccionado != null &&
      !(w.state.modoSeleccionado == 'premium' && !w.state.codigoValido) &&
      !w.state.guardando;
  final bloc = context.read<SetupBloc>();
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: w.r.spacingXL),
    child: SizedBox(
      height: w.r.continueButtonHeight,
      child: Row(
        children: [
          Expanded(
            child: BotonVidrio(
              label: w.loc.setup.back,
              onPressed: () => bloc.add(const PasoAnterior()),
              height: w.r.continueButtonHeight,
              accent: glowColor,
            ),
          ),
          SizedBox(width: w.r.spacingM),
          Expanded(
            child: BotonVidrio(
              label: w.loc.setup.next,
              onPressed:
                  nextOk ? () => bloc.add(const SiguientePaso()) : null,
              isLoading: w.state.guardando,
              height: w.r.continueButtonHeight,
              accent: glowColor,
            ),
          ),
        ],
      ),
    ),
  );
}