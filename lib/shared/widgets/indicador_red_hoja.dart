// ─────────────────────────────────────────────────────────────
// indicador_red_hoja.dart — PART de indicador_red.dart: hoja inferior
// de detalle del estado de red — nivel medido, tipo de conexión,
// latencia real y un botón para volver a medir al instante. Se
// reconstruye sola con el ValueListenable del servicio, así que el
// botón de remedición refresca los datos sin cerrar la hoja.
// Se conecta con: indicador_red.dart (misma library) +
// servicio_calidad_red + l10n (StringsRed) + contenedor_vidrio.
// Parte del flujo: Home → barra superior → detalle de red.
// ─────────────────────────────────────────────────────────────

part of 'indicador_red.dart';

/// Etiqueta legible del tipo de conexión.
String etiquetaTipoRed(AppLocalizations loc, TipoRed tipo) {
  switch (tipo) {
    case TipoRed.wifi:
      return loc.red.typeWifi;
    case TipoRed.movil:
      return loc.red.typeMobile;
    case TipoRed.ethernet:
      return loc.red.typeEthernet;
    case TipoRed.otra:
      return loc.red.typeOther;
    case TipoRed.ninguna:
      return loc.red.typeNone;
  }
}

/// Abre la hoja de detalle del estado de red.
Future<void> mostrarHojaEstadoRed(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _HojaEstadoRed(),
  );
}

class _HojaEstadoRed extends StatelessWidget {
  const _HojaEstadoRed();

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(esOscuro);
    final loc = AppLocalizations.of(context);

    return ValueListenableBuilder<EstadoCalidadRed>(
      valueListenable: ServicioCalidadRed.instancia.estado,
      builder: (context, estado, _) {
        final color = colorNivelRed(estado.nivel, estado.tipo, onBg);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            r.spacingL,
            0,
            r.spacingL,
            MediaQuery.of(context).viewInsets.bottom + r.spacingXL,
          ),
          child: ContenedorVidrio(
            borderRadius: 22,
            borderColor: onBg.withValues(alpha: 0.08),
            bgColor: ColoresApp.superficie(esOscuro).withValues(alpha: 0.96),
            padding: EdgeInsets.all(r.spacingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _manija(r, onBg),
                SizedBox(height: r.spacingM),
                Row(
                  children: [
                    Icon(iconoTipoRed(estado), size: r.titleSize * 1.3, color: color),
                    SizedBox(width: r.spacingS),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.red.title,
                            style: TextStyle(
                              fontSize: r.footerSize,
                              color: onBg.withValues(alpha: 0.5),
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            etiquetaNivelRed(loc, estado.nivel),
                            style: TextStyle(
                              fontSize: r.subtitleSize + 4,
                              fontWeight: FontWeight.w800,
                              color: onBg,
                            ),
                          ),
                        ],
                      ),
                    ),
                    BarrasCalidadRed(
                      nivel: estado.nivel,
                      midiendo: estado.midiendo,
                      onBg: onBg,
                    ),
                  ],
                ),
                SizedBox(height: r.spacingM),
                _filaDato(
                  r: r,
                  onBg: onBg,
                  etiqueta: loc.red.latencyLabel,
                  valor: estado.latenciaMs >= 0
                      ? '${estado.latenciaMs} ms'
                      : loc.red.unavailable,
                ),
                _filaDato(
                  r: r,
                  onBg: onBg,
                  etiqueta: loc.red.sourcesLabel,
                  valor: etiquetaTipoRed(loc, estado.tipo),
                ),
                SizedBox(height: r.spacingM),
                Text(
                  loc.red.detailHint,
                  style: TextStyle(
                    fontSize: r.footerSize - 1,
                    color: onBg.withValues(alpha: 0.4),
                  ),
                ),
                SizedBox(height: r.spacingM),
                _botonMedir(context, r, onBg, estado.midiendo),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Manija superior de la hoja.
  Widget _manija(Responsive r, Color onBg) => Center(
        child: Container(
          width: r.val(36, 28, 46),
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: onBg.withValues(alpha: 0.18),
          ),
        ),
      );

  /// Fila etiqueta/valor de la hoja.
  Widget _filaDato({
    required Responsive r,
    required Color onBg,
    required String etiqueta,
    required String valor,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.spacingXS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            etiqueta,
            style: TextStyle(
              fontSize: r.subtitleSize,
              color: onBg.withValues(alpha: 0.55),
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: r.subtitleSize,
              fontWeight: FontWeight.w700,
              color: onBg,
            ),
          ),
        ],
      ),
    );
  }

  /// Botón para forzar una remedición inmediata.
  Widget _botonMedir(
    BuildContext context,
    Responsive r,
    Color onBg,
    bool midiendo,
  ) {
    final loc = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      height: r.continueButtonHeight,
      child: GestureDetector(
        onTap: midiendo ? null : () => ServicioCalidadRed.instancia.medirAhora(),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: onBg.withValues(alpha: 0.12)),
            color: onBg.withValues(alpha: 0.04),
          ),
          child: Text(
            midiendo ? loc.red.measuring : loc.setup.retry,
            style: TextStyle(
              fontSize: r.subtitleSize,
              fontWeight: FontWeight.w600,
              color: onBg.withValues(alpha: midiendo ? 0.5 : 0.9),
            ),
          ),
        ),
      ),
    );
  }
}
