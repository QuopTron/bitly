// ─────────────────────────────────────────────────────────────
// settings_conexion_trial.dart — PART de settings_sheet_new.dart: la
// tarjeta de la PRUEBA de 9 horas de la conexión multi (solo free).
//
// Explica el trato: con free hay un aparato, y la prueba habilita los
// cuatro durante 9 horas de USO (el reloj corre solo mientras se usa).
// Mientras corre, muestra cuánto queda; cuando se agota, lo dice y deja
// de ofrecerse. Todavía sin arrancar, ofrece el botón.
//
// Solo aparece para los free: si el usuario ya es premium, el cupo
// completo no es una prueba, es su plan.
//
// Se conecta con: settings_conexion_tab.dart (misma library) +
// servicio_conexion + trial_conexion.
// Parte del flujo: Ajustes → Conexión (prueba de la multi-conexión).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Tarjeta de la prueba de 9 horas.
class _TarjetaTrial extends StatelessWidget {
  final ServicioConexion servicio;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final VoidCallback onCambio;

  const _TarjetaTrial({
    required this.servicio,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).conexion;
    return ContenedorVidrio(
      borderRadius: 14,
      borderColor: onBg.withValues(alpha: 0.08),
      bgColor: onBg.withValues(alpha: 0.03),
      padding: EdgeInsets.all(r.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                color: glowColor,
                size: r.subtitleSize,
              ),
              SizedBox(width: r.spacingS),
              Expanded(
                child: Text(
                  t.trialTitulo,
                  style: TextStyle(
                    fontSize: r.footerSize + 1,
                    fontWeight: FontWeight.w700,
                    color: onBg,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: r.spacingXS),
          Text(
            t.trialAyuda,
            style: TextStyle(
              fontSize: r.footerSize - 2,
              color: onBg.withValues(alpha: 0.5),
              height: 1.35,
            ),
          ),
          SizedBox(height: r.spacingS),
          _accion(context, t),
          SizedBox(height: r.spacingXS),
          Text(
            t.premiumAyuda,
            style: TextStyle(
              fontSize: r.footerSize - 2,
              color: onBg.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }

  /// Estado de la prueba: ofrecerla, mostrar lo que queda o decir que se
  /// terminó. Nunca se ofrece de nuevo si ya se agotó.
  Widget _accion(BuildContext context, StringsConexion t) {
    final trial = servicio.trial;
    final ahora = DateTime.now().millisecondsSinceEpoch;
    if (trial.sirveEn(ahora)) {
      final (horas, minutos) = trial.restanteEnHorasMinutos(ahora);
      return Row(
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: glowColor),
          SizedBox(width: r.spacingXS),
          Expanded(
            child: Text(
              t.trialRestante(horas, minutos),
              style: TextStyle(
                fontSize: r.footerSize,
                fontWeight: FontWeight.w600,
                color: glowColor,
              ),
            ),
          ),
        ],
      );
    }
    if (trial.terminadaEn(ahora)) {
      return Text(
        t.trialAgotada,
        style: TextStyle(
          fontSize: r.footerSize - 2,
          color: onBg.withValues(alpha: 0.45),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: () async {
          await servicio.iniciarTrial();
          onCambio();
        },
        child: Text(t.trialArrancar),
      ),
    );
  }
}
