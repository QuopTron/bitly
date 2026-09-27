// miniplayer_controles.dart — PART de miniplayer.dart: botón circular
// de play/pausa (con spinner en buffering) y la fila inferior de
// progreso con tiempos. Despachan al cubit del reproductor.
//
// El botón toma su diámetro del `Responsive` que recibe del padre (que ya
// sabe del aparato): en la TV es bastante más grande, porque se toca con el
// puntero del control.

part of '../base/miniplayer.dart';

/// Botón circular de play/pausa (con spinner en buffering).
Widget _botonPlayMini(
  _MiniplayerState st,
  Responsive r,
  Color fg,
  EstadoAudioReproductor player,
  bool buffering,
) {
  final lado = r.val(42, 38, 78);
  return GestureDetector(
    onTap: () {
      Haptico.medio();
      st.context.read<CubitReproductor>().alternarReproduccion();
    },
    child: Container(
      width: lado,
      height: lado,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fg.withValues(alpha: 0.12),
      ),
      child: Center(
        child:
            buffering
                ? SizedBox(
                  width: lado * 0.48,
                  height: lado * 0.48,
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
                  // Escala de iconos de las BARRAS (navbar y miniplayer),
                  // separada de la de las tarjetas.
                  size: lado * 0.66 * EscalaUi.factorIconosBarras,
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
