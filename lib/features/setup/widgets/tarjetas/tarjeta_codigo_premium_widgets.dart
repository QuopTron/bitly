// ─────────────────────────────────────────────────────────────
// tarjeta_codigo_premium_widgets.dart — PART de
// tarjeta_codigo_premium.dart: sub-widgets de la tarjeta de código
// premium (campo de texto con vidrio y sufijo de estado, fila de
// error y botón de activar/reintentar con su lógica de habilitado).
// Las funciones reciben la tarjeta para acceder a sus campos
// (state, loc, r, onBg, glowColor).
// Se conecta con: tarjeta_codigo_premium.dart (misma library) +
// shared (vidrio, botón) + setup_bloc.
// Parte del flujo: setup (paso 5: modo premium → código).
// ─────────────────────────────────────────────────────────────

part of 'tarjeta_codigo_premium.dart';

Widget _campo(BuildContext context, TarjetaCodigoPremium t) {
  return ContenedorVidrio(
    borderRadius: 10,
    borderColor: t.state.errorCodigo != null
        ? Colors.redAccent.withValues(alpha: 0.4)
        : t.onBg.withValues(alpha: 0.08),
    bgColor: t.onBg.withValues(alpha: 0.03),
    child: TextField(
      decoration: InputDecoration(
        hintText: t.loc.setup.codePlaceholder,
        hintStyle: TextStyle(
          color: t.onBg.withValues(alpha: 0.35),
          fontSize: t.r.footerSize,
        ),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(
          horizontal: t.r.spacingM,
          vertical: t.r.spacingS + 2,
        ),
        suffixIcon: t.state.codigoValido
            ? Icon(Icons.check_circle, color: t.glowColor, size: 18)
            : t.state.errorCodigo != null
                ? Icon(Icons.cancel, color: Colors.redAccent, size: 18)
                : null,
      ),
      style: TextStyle(color: t.onBg, fontSize: t.r.subtitleSize),
      onChanged: (val) =>
          context.read<SetupBloc>().add(CodigoPremiumCambiado(val)),
    ),
  );
}

Widget _error(BuildContext context, TarjetaCodigoPremium t) {
  return ContenedorVidrio(
    borderRadius: 10,
    borderColor: Colors.redAccent.withValues(alpha: 0.3),
    bgColor: Colors.redAccent.withValues(alpha: 0.06),
    padding: EdgeInsets.symmetric(horizontal: t.r.spacingM, vertical: t.r.spacingS),
    child: Row(
      children: [
        Icon(Icons.cancel, color: Colors.redAccent, size: 16),
        SizedBox(width: t.r.spacingS),
        Expanded(
          child: Text(
            t.state.errorCodigo!,
            style: TextStyle(color: Colors.redAccent, fontSize: t.r.footerSize),
          ),
        ),
      ],
    ),
  );
}

Widget _boton(BuildContext context, TarjetaCodigoPremium t) {
  final hasError = t.state.errorCodigo != null;
  final enabled = !t.state.validandoCodigo &&
      !t.state.codigoValido &&
      t.state.codigoPremium.trim().isNotEmpty;
  return BotonVidrio(
    label: t.state.codigoValido
        ? t.loc.setup.codeActivated
        : hasError
            ? t.loc.setup.retry
            : t.loc.setup.activate,
    icon: t.state.codigoValido
        ? Icon(Icons.check_circle, size: 16, color: t.glowColor)
        : hasError
            ? Icon(Icons.refresh, size: 16, color: Colors.redAccent)
            : null,
    onPressed: enabled
        ? () => context.read<SetupBloc>().add(const ValidarCodigoPremium())
        : null,
    isLoading: t.state.validandoCodigo,
    height: t.r.continueButtonHeight * 0.85,
    accent: hasError ? Colors.redAccent : t.glowColor,
  );
}