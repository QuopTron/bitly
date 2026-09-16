// ─────────────────────────────────────────────────────────────
// hoja_letras_transporte_progreso.dart — PART de hoja_letras.dart:
// la seek bar del karaoke (tiempo actual, barra y duración).
//
// Se extrajo de hoja_letras_transporte.dart para que ese archivo no
// pase de 150 líneas: acá vive solo el progreso, no los controles.
//
// Se conecta con: hoja_letras.dart (misma library) + cubit del
// reproductor + Responsive.
// Parte del flujo: reproductor (letras, transporte).
// ─────────────────────────────────────────────────────────────

part of 'hoja_letras.dart';

/// Barra de progreso: tiempo actual, slider y duración total.
Widget _filaProgreso(
  Responsive r,
  bool esOscuro,
  EstadoAudioReproductor reproductor,
) {
  final fg = esOscuro ? Colors.white : Colors.black;
  final tenue = fg.withValues(alpha: 0.5);
  final total = reproductor.duracion.inMilliseconds;

  return Padding(
    padding: EdgeInsets.symmetric(horizontal: r.spacingM),
    child: Row(
      children: [
        Text(
          _formatearDuracion(reproductor.posicion),
          style: TextStyle(fontSize: r.footerSize, color: tenue),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: fg.withValues(alpha: 0.7),
              inactiveTrackColor: fg.withValues(alpha: 0.12),
              thumbColor: fg.withValues(alpha: 0.8),
            ),
            child: Slider(
              value: total > 0
                  ? (reproductor.posicion.inMilliseconds / total).clamp(0.0, 1.0)
                  : 0.0,
              onChangeEnd: (v) => sl<CubitReproductor>().buscarAProgreso(v),
              onChanged: (_) {},
            ),
          ),
        ),
        Text(
          _formatearDuracion(reproductor.duracion),
          style: TextStyle(fontSize: r.footerSize, color: tenue),
        ),
      ],
    ),
  );
}
