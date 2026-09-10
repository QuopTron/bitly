// ─────────────────────────────────────────────────────────────
// miniplayer_build.dart — PART de miniplayer.dart: build del
// miniplayer — BlocBuilder de cola + reproductor que arma la barra
// con blur de fondo, swipe horizontal para cambiar de canción y
// las dos filas (track + progreso). Los widgets de piezas viven
// en miniplayer_animacion/pintor/progreso.
// Se conecta con: miniplayer.dart (misma library) + cubits.
// Parte del flujo: Home (miniplayer sobre el shell).
// ─────────────────────────────────────────────────────────────

part of 'miniplayer.dart';

/// Construye el miniplayer con los cubits de cola y reproductor.
Widget _buildMiniplayer(
  _MiniplayerState st,
  BuildContext context,
) {
  final r = Responsive(context);
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  final fg = ColoresApp.enSuperficie(esOscuro);      return BlocBuilder<CubitCola, EstadoCola>(
    builder: (context, cola) {
      if (!cola.tieneActual) return const SizedBox.shrink();
      final track = cola.actual!;
      // buildWhen: ignorar ticks de posición (mpv emite ~25/s). Solo
      // reconstruir cuando cambia duración/estado/volumen/velocidad para
      // no recomputar carátula ni recompositar el fondo en cada tick.
      return BlocBuilder<CubitReproductor, EstadoAudioReproductor>(
        buildWhen: (prev, curr) =>
            prev.duracion != curr.duracion ||
            prev.estadoReproduccion != curr.estadoReproduccion ||
            prev.volumen != curr.volumen ||
            prev.velocidad != curr.velocidad ||
            prev.mensajeError != curr.mensajeError,
        builder: (context, player) {
          final caratula =
              context.read<CubitLikes>().caratulaLocalPara(track);
          final buffering =
              player.estadoReproduccion == EstadoReproduccion.buffering;

          return _WidgetAnimadoTrack(
            key: ValueKey('mp_tween_${track.id}'),
            trackId: track.id,
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0;
                if (v > 300) {
                  Haptico.tap();
                  context.read<CubitReproductor>().anterior();
                } else if (v < -300) {
                  Haptico.tap();
                  context.read<CubitReproductor>().siguiente();
                }
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: r.width * 0.04),
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                  // Sin BackdropFilter: el fondo es 100% opaco, el blur no se
                  // ve y su compositing cuesta GPU en CADA frame. RepaintBoundary
                  // aísla el repintado del miniplayer del contenido de Home.
                  child: RepaintBoundary(
                    child: Container(
                      decoration: BoxDecoration(
                        // Fondo opaco: evita líneas fantasma del contenido
                        // que pasa por debajo del miniplayer.
                        color: esOscuro
                            ? const Color(0xFF0B0B14)
                            : const Color(0xFFFFFFFF),
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(8)),
                        border: Border.all(
                          color: fg.withValues(alpha: 0.1),
                          width: 0.5,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: r.spacingS,
                          vertical: r.spacingXS * 0.5,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _filaTrackMini(st, r, fg, esOscuro, cola, player,
                                track, caratula, buffering),
                            _FilaProgresoAutonoma(st: st, r: r, fg: fg),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}