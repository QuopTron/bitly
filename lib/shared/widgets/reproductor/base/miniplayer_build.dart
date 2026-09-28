// ─────────────────────────────────────────────────────────────
// miniplayer_build.dart — PART de miniplayer.dart: build del miniplayer.
// BlocBuilder de cola + reproductor que arma la barra con blur de fondo,
// swipe para cambiar de canción y las dos filas (track + progreso). Las
// piezas viven en _animacion / _pintor / _progreso.
// Se conecta con: miniplayer.dart (misma library) + cubits.
// Parte del flujo: Home (miniplayer sobre el shell).
// ─────────────────────────────────────────────────────────────

part of 'miniplayer.dart';

/// Construye el miniplayer con los cubits de cola y reproductor, envuelto en
/// las preferencias de apariencia (forma, trazo, color y adorno al instante).
Widget _buildMiniplayer(_MiniplayerState st, BuildContext context) =>
    ValueListenableBuilder<PreferenciasApariencia>(
      valueListenable: AparienciaHelper.notifier(),
      builder:
          (context, prefs, _) => _buildMiniplayerConPrefs(st, context, prefs),
    );

Widget _buildMiniplayerConPrefs(
  _MiniplayerState st,
  BuildContext context,
  PreferenciasApariencia prefs,
) {
  final r = Responsive(context);
  // Las medidas del miniplayer (carátula, iconos) salen de la geometría, que ya
  // resolvió el aparato Y el preset de tamaño elegido en Ajustes.
  final g = geometriaMiniplayerDe(context);
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  final fg = ColoresApp.enSuperficie(esOscuro);
  return BlocBuilder<CubitCola, EstadoCola>(
    builder: (context, cola) {
      if (!cola.tieneActual) return const SizedBox.shrink();
      final track = cola.actual!;
      // buildWhen: ignora los ticks de posición (mpv emite ~25/s) y solo
      // reconstruye si cambian duración/estado/volumen/velocidad.
      return BlocBuilder<CubitReproductor, EstadoAudioReproductor>(
        buildWhen:
            (prev, curr) =>
                prev.duracion != curr.duracion ||
                prev.estadoReproduccion != curr.estadoReproduccion ||
                prev.volumen != curr.volumen ||
                prev.velocidad != curr.velocidad ||
                prev.codigoError != curr.codigoError,
        builder: (context, player) {
          final caratula = context.read<CubitLikes>().caratulaLocalPara(track);
          final buffering =
              player.estadoReproduccion == EstadoReproduccion.buffering;
          // Contorno elegido por el usuario (Ajustes → Apariencia → Barras).
          final trazo = AparienciaBarras.trazoBorde(context);
          final radio = BorderRadius.vertical(
            top: Radius.circular(prefs.radioMiniplayer),
          );
          // Paleta del cofre: tiñe el fondo opaco. Sin paleta queda como hoy.
          final paleta = AparienciaBarras.paletaBarra(context, navbar: false);
          final base =
              esOscuro ? const Color(0xFF0B0B14) : const Color(0xFFFFFFFF);
          final gradiente = AparienciaPaleta.gradiente(
            paleta,
            esOscuro: esOscuro,
            base: base,
          );
          final bordePaleta = AparienciaPaleta.borde(
            paleta,
            esOscuro: esOscuro,
          );
          // Adorno del cofre: esquinas u OLAS, más su calcomanía si la trae.
          final adorno = AparienciaDisenos.adornoDe(context, navbar: false);
          final esOlas = adorno == AdornoBarra.olas;
          final olas = AparienciaDisenos.olasDe(context, navbar: false);
          final sticker = AparienciaDisenos.stickerDe(context, navbar: false);

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
                // El relleno se mide contra la BARRA (no contra la pantalla):
                // con el ancho acotado, el 4% de una pantalla enorme se comía
                // el contenido.
                padding: EdgeInsets.symmetric(horizontal: g.paddingInterno),
                child: BarraAdornada(
                  adorno: adorno,
                  olas: olas,
                  radioArriba: prefs.radioMiniplayer,
                  colorBorde: bordePaleta ?? fg.withValues(alpha: 0.22),
                  sticker: sticker,
                  colorSticker: bordePaleta ?? fg.withValues(alpha: 0.75),
                  // Sin BackdropFilter: el fondo es opaco y su compositing
                  // costaría GPU en CADA frame. RepaintBoundary lo aísla.
                  child: RepaintBoundary(
                    child: Container(
                      decoration: BoxDecoration(
                        // Fondo opaco: evita líneas fantasma del contenido de
                        // abajo. Con paleta va el gradiente, mezclado sobre el
                        // color base.
                        color: gradiente == null ? base : null,
                        gradient: gradiente,
                        borderRadius: esOlas ? BorderRadius.zero : radio,
                        // Con olas el contorno lo pinta el adorno, siguiendo
                        // la ola: acá no se dibuja una línea recta arriba.
                        border:
                            trazo.$2 == 0 || esOlas
                                ? null
                                : Border.all(
                                  color:
                                      bordePaleta ??
                                      fg.withValues(alpha: trazo.$1),
                                  width: trazo.$2,
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
                            _filaTrackMini(
                              st,
                              r,
                              g,
                              fg,
                              esOscuro,
                              cola,
                              player,
                              track,
                              caratula,
                              buffering,
                            ),
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
