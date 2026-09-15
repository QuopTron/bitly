// ─────────────────────────────────────────────────────────────
// indicador_red_hoja.dart — PART de indicador_red.dart: hoja inferior
// de detalle del estado de red — nivel medido, tipo de conexión,
// latencia real y un botón para volver a medir al instante.
// Se conecta con: indicador_red.dart (misma library) +
// servicio_calidad_red + l10n + contenedor_vidrio.
// Parte del flujo: Home → barra superior → detalle de red.
// ─────────────────────────────────────────────────────────────

part of 'indicador_red.dart';

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
                manijaHojaRed(r, onBg),
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
                filaDatoHojaRed(
                  r: r,
                  onBg: onBg,
                  etiqueta: loc.red.latencyLabel,
                  valor: estado.latenciaMs >= 0
                      ? '${estado.latenciaMs} ms'
                      : loc.red.unavailable,
                ),
                filaDatoHojaRed(
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
                botonMedirHojaRed(context, r, onBg, estado.midiendo),
              ],
            ),
          ),
        );
      },
    );
  }
}
