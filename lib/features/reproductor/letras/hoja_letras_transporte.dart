// ─────────────────────────────────────────────────────────────
// hoja_letras_transporte.dart — PART de hoja_letras.dart: fila de
// transporte rápida mientras el karaoke está abierto — seek bar
// (tiempo actual / total) y los controles prev / play / next /
// repeat / shuffle con blancos de toque grandes.
// Se conecta con: hoja_letras.dart (misma library) + cubits.
// Parte del flujo: reproductor (letras, transporte).
// ─────────────────────────────────────────────────────────────

part of 'hoja_letras.dart';

/// Fila inferior de controles rápidos del karaoke.
Widget _filaTransporte(
  BuildContext context,
  Responsive r,
  bool esOscuro,
  EstadoAudioReproductor reproductor,
) {
  final fg = esOscuro ? Colors.white : Colors.black;
  final apagado = fg.withValues(alpha: 0.45);
  final iconoS = r.subtitleSize + 8; // iconos más grandes
  final playS = r.subtitleSize + 40;
  final gap = r.spacingL + 4;

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: r.spacingM),
        child: Row(
          children: [
            Text(
              _formatearDuracion(reproductor.posicion),
              style: TextStyle(
                  fontSize: r.footerSize, color: fg.withValues(alpha: 0.5)),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: fg.withValues(alpha: 0.7),
                  inactiveTrackColor: fg.withValues(alpha: 0.12),
                  thumbColor: fg.withValues(alpha: 0.8),
                ),
                child: Slider(
                  value: reproductor.duracion.inMilliseconds > 0
                      ? (reproductor.posicion.inMilliseconds /
                              reproductor.duracion.inMilliseconds)
                          .clamp(0.0, 1.0)
                      : 0.0,
                  onChangeEnd: (v) =>
                      sl<CubitReproductor>().buscarAProgreso(v),
                  onChanged: (_) {},
                ),
              ),
            ),
            Text(
              _formatearDuracion(reproductor.duracion),
              style: TextStyle(
                  fontSize: r.footerSize, color: fg.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => sl<CubitCola>().anterior(),
            child:
                Icon(Icons.skip_previous_rounded, color: fg, size: iconoS + 4),
          ),
          SizedBox(width: gap),
          GestureDetector(
            onTap: () => sl<CubitReproductor>().alternarReproduccion(),
            child: Container(
              width: playS,
              height: playS,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fg.withValues(alpha: 0.14),
                border: Border.all(color: fg.withValues(alpha: 0.2)),
              ),
              child: Icon(
                reproductor.estaReproduciendo
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: fg,
                size: playS * 0.58,
              ),
            ),
          ),
          SizedBox(width: gap),
          BlocBuilder<CubitCola, EstadoCola>(
            builder: (context, cola) => GestureDetector(
              onTap: () => sl<CubitCola>().siguiente(),
              child: Icon(Icons.skip_next_rounded, color: fg, size: iconoS + 4),
            ),
          ),
          SizedBox(width: gap),
          BlocBuilder<CubitCola, EstadoCola>(
            builder: (context, cola) => GestureDetector(
              onTap: () => sl<CubitCola>().ciclarModoRepeticion(),
              child: Icon(
                cola.modoRepeticion == ModoRepeticion.uno
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                color: cola.modoRepeticion != ModoRepeticion.ninguno
                    ? fg
                    : apagado,
                size: iconoS,
              ),
            ),
          ),
          SizedBox(width: gap),
          BlocBuilder<CubitCola, EstadoCola>(
            builder: (context, cola) => GestureDetector(
              onTap: () => sl<CubitCola>().alternarShuffle(),
              child: Icon(
                Icons.shuffle_rounded,
                color: cola.shuffle ? fg : apagado,
                size: iconoS,
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: r.spacingS),
    ],
  );
}