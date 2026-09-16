// ─────────────────────────────────────────────────────────────
// hoja_letras_transporte.dart — PART de hoja_letras.dart: fila de
// transporte rápida mientras el karaoke está abierto — la seek bar
// (en _progreso) y los controles prev / play / next / repeat /
// shuffle con blancos de toque grandes.
//
// La fila de controles va dentro de un FittedBox: en pantallas
// angostas o con DPI grande se encoge en bloque en vez de desbordar.
//
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
      _filaProgreso(r, esOscuro, reproductor),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => sl<CubitCola>().anterior(),
              child: Icon(
                Icons.skip_previous_rounded,
                color: fg,
                size: iconoS + 4,
              ),
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
              builder:
                  (context, cola) => GestureDetector(
                    onTap: () => sl<CubitCola>().siguiente(),
                    child: Icon(
                      Icons.skip_next_rounded,
                      color: fg,
                      size: iconoS + 4,
                    ),
                  ),
            ),
            SizedBox(width: gap),
            BlocBuilder<CubitCola, EstadoCola>(
              builder:
                  (context, cola) => GestureDetector(
                    onTap: () => sl<CubitCola>().ciclarModoRepeticion(),
                    child: Icon(
                      cola.modoRepeticion == ModoRepeticion.uno
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color:
                          cola.modoRepeticion != ModoRepeticion.ninguno
                              ? fg
                              : apagado,
                      size: iconoS,
                    ),
                  ),
            ),
            SizedBox(width: gap),
            BlocBuilder<CubitCola, EstadoCola>(
              builder:
                  (context, cola) => GestureDetector(
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
      ),
      SizedBox(height: r.spacingS),
    ],
  );
}
