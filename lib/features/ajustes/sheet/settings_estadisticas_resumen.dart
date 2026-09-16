// ─────────────────────────────────────────────────────────────
// settings_estadisticas_resumen.dart — PART de settings_sheet_new
// .dart: cabecera de la pestaña Estadísticas con los números que
// resumen la escucha (horas, temas, artistas y descargas).
//
// Sale del MISMO dato local que usa el perfil (EstadisticasUsuario):
// no hay un segundo contador que pueda divergir.
//
// Se conecta con: settings_sheet_new.dart (misma library) +
// settings_compartidos_tab.dart (lo usa).
// Parte del flujo: Ajustes → Estadísticas.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Cabecera con lo esencial de la escucha: horas, temas distintos,
/// artistas y descargas.
class _ResumenEscucha extends StatelessWidget {
  final EstadisticasUsuario? stats;
  final int milisegundos;
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const _ResumenEscucha({
    required this.stats,
    required this.milisegundos,
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final datos = stats;
    // Etiquetas localizadas: el resumen se lee en el idioma de la app.
    final s = AppLocalizations.of(context).estadisticas;
    final items = <(IconData, String, String)>[
      (Icons.schedule_rounded, s.resumenHoras, '${milisegundos ~/ 3600000}'),
      (Icons.music_note_rounded, s.resumenTemas, '${datos?.totalTracks ?? 0}'),
      (Icons.person_rounded, s.resumenArtistas, '${datos?.totalArtistas ?? 0}'),
      (Icons.download_rounded, s.resumenDescargas,
          '${datos?.totalDescargas ?? 0}'),
    ];
    // Tocar el resumen abre el DETALLE con filtros: los cuatro números son la
    // puerta a "todo lo que escuché", no el final del camino.
    return GestureDetector(
      onTap: () => mostrarDetalleEscucha(context, glowColor: glowColor),
      child: Container(
        padding: EdgeInsets.all(r.spacingM),
        decoration: BoxDecoration(
          color: glowColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: glowColor.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            for (final (icono, etiqueta, valor) in items)
              Expanded(
                child: Column(
                  children: [
                    Icon(icono, size: r.subtitleSize, color: glowColor),
                    SizedBox(height: r.spacingXS),
                    Text(
                      valor,
                      style: TextStyle(
                        fontSize: r.subtitleSize,
                        fontWeight: FontWeight.w700,
                        color: onBg,
                      ),
                    ),
                    Text(
                      etiqueta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: r.footerSize - 2,
                        color: onBg.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            // Aviso de que la tarjeta se puede tocar.
            Icon(
              Icons.chevron_right_rounded,
              size: r.subtitleSize,
              color: onBg.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
