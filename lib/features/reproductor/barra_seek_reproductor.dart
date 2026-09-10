// ─────────────────────────────────────────────────────────────
// barra_seek_reproductor.dart — Barra de progreso del NowPlaying:
// slider sobre la posición del track (busca al soltar) con los
// tiempos transcurrido y restante formateados. Recibe el estado
// del reproductor y despacha la búsqueda al cubit.
// Se conecta con: cubit_reproductor + responsive.
// Parte del flujo: reproductor (NowPlaying, seek).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/cache/estado_reproductor.dart';
import '../../shared/utilidades/responsive.dart';
import '../../estado/cubit_reproductor.dart';

/// Slider de progreso con tiempos transcurrido / restante. Se suscribe él
/// mismo al cubit (buildWhen: solo posición/duración) para que la página del
/// reproductor NO reconstruya el fondo blur en cada tick de mpv (~25/s).
class BarraSeekReproductor extends StatelessWidget {
  final Responsive r;
  final bool esOscuro;

  const BarraSeekReproductor({
    super.key,
    required this.r,
    required this.esOscuro,
  });

  @override
  Widget build(BuildContext context) {
    final fg = esOscuro ? Colors.white : Colors.black;
    return BlocBuilder<CubitReproductor, EstadoAudioReproductor>(
      buildWhen: (prev, curr) =>
          prev.posicion != curr.posicion ||
          prev.duracion != curr.duracion,
      builder: (context, estado) {
        final duracion = estado.duracion;
        final posicion = estado.posicion;
        final restante = duracion - posicion;

        return Column(
          children: [
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                activeTrackColor: fg.withValues(alpha: 0.7),
                inactiveTrackColor: fg.withValues(alpha: 0.15),
                thumbColor: fg.withValues(alpha: 0.8),
                overlayColor: fg.withValues(alpha: 0.15),
              ),
              child: Slider(
                value: estado.progreso.clamp(0.0, 1.0),
                onChanged: (v) =>
                    context.read<CubitReproductor>().buscarAProgreso(v),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.spacingS),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatearDuracion(posicion),
                    style: TextStyle(
                      fontSize: r.footerSize,
                      color: fg.withValues(alpha: 0.5),
                    ),
                  ),
                  Text(
                    '-${_formatearDuracion(restante)}',
                    style: TextStyle(
                      fontSize: r.footerSize,
                      color: fg.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Formatea una duración como m:ss o h:mm:ss.
  String _formatearDuracion(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final minutos = d.inMinutes.remainder(60);
    final segundos = d.inSeconds.remainder(60);
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}'
        '${minutos.toString().padLeft(2, '0')}:'
        '${segundos.toString().padLeft(2, '0')}';
  }
}