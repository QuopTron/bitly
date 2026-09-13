// miniplayer_controles.dart — PART de miniplayer.dart: botón circular
// de play/pausa (con spinner en buffering) y la fila inferior de
// progreso con tiempos. Despachan al cubit del reproductor.

part of 'miniplayer.dart';

/// Botón circular de play/pausa (con spinner en buffering).
Widget _botonPlayMini(
  _MiniplayerState st,
  Responsive r,
  Color fg,
  EstadoAudioReproductor player,
  bool buffering,
) {
  return GestureDetector(
    onTap: () {
      Haptico.medio();
      st.context.read<CubitReproductor>().alternarReproduccion();
    },
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fg.withValues(alpha: 0.12),
      ),
      child: Center(
        child: buffering
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: fg.withValues(alpha: 0.7),
                ),
              )
            : Icon(
                player.estaReproduciendo
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: fg,
                size: 28,
              ),
      ),
    ),
  );
}

/// Formatea una duración como m:ss o h:mm:ss.
String _formatearDuracionMini(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return '${d.inHours > 0 ? '${d.inHours}:' : ''}'
      '${m.toString().padLeft(2, '0')}:'
      '${s.toString().padLeft(2, '0')}';
}