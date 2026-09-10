// ─────────────────────────────────────────────────────────────
// fila_controles_reproductor.dart — Controles principales del
// NowPlaying: like, shuffle, anterior, play/pausa, siguiente,
// repetición y letras. FittedBox escala la fila en pantallas
// angostas (sin overflow). Los iconos usan el estado del cubit.
// El botón circular de play/pausa vive en BotonPlayReproductor.
// Se conecta con: cubit_cola + cubit_reproductor + cubit_like +
// haptico + responsive.
// Parte del flujo: reproductor (NowPlaying, controles).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/inyeccion.dart';
import '../../core/cache/estado_cola.dart';
import '../../core/cache/estado_like.dart';
import '../../core/cache/estado_reproductor.dart';
import '../../core/modelos/item_feed.dart';
import '../../estado/cubit_cola.dart';
import '../../estado/cubit_like.dart';
import '../../estado/cubit_reproductor.dart';
import '../../shared/utilidades/haptico.dart';
import '../../shared/utilidades/responsive.dart';

part 'fila_controles_botones.dart';

/// Fila de botones de control del reproductor completo.
class FilaControlesReproductor extends StatelessWidget {
  final Responsive r;
  final bool esOscuro;
  final EstadoCola cola;
  final ItemFeed track;
  final bool letrasCargando;
  final VoidCallback? onAlternarLetras;

  const FilaControlesReproductor({
    super.key,
    required this.r,
    required this.esOscuro,
    required this.cola,
    required this.track,
    this.letrasCargando = false,
    this.onAlternarLetras,
  });

  @override
  Widget build(BuildContext context) {
    final apagado =
        (esOscuro ? Colors.white : Colors.black).withValues(alpha: 0.45);
    final activo = esOscuro ? Colors.white : Colors.black;
    final iconoM = r.subtitleSize + 7;
    final iconoL = r.subtitleSize + 13;
    final gap = r.spacingL;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _botonLike(this, activo, apagado, iconoM),
          SizedBox(width: gap),
          _botonShuffle(this, activo, apagado, iconoM),
          SizedBox(width: gap),
          _botonAnterior(activo, iconoL),
          SizedBox(width: gap),
          BotonPlayReproductor(r: r, activo: activo),
          SizedBox(width: gap),
          _botonSiguiente(activo, iconoL),
          SizedBox(width: gap),
          _botonRepeticion(this, activo, apagado, iconoM),
          SizedBox(width: r.spacingS),
          _botonLetras(this, apagado),
        ],
      ),
    );
  }
}

/// Botón circular de play/pausa (con spinner en buffering).
class BotonPlayReproductor extends StatelessWidget {
  final Responsive r;
  final Color activo;

  const BotonPlayReproductor({super.key, required this.r, required this.activo});

  @override
  Widget build(BuildContext context) {
    final reproductor = context.read<CubitReproductor>().state;
    return GestureDetector(
      onTap: () {
        Haptico.medio();
        sl<CubitReproductor>().alternarReproduccion();
      },
      child: Container(
        width: r.subtitleSize + 40,
        height: r.subtitleSize + 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: activo.withValues(alpha: 0.12),
          border: Border.all(
            color: activo.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: reproductor.estadoReproduccion == EstadoReproduccion.buffering
            ? Center(
                child: SizedBox(
                  width: r.subtitleSize + 4,
                  height: r.subtitleSize + 4,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor:
                        AlwaysStoppedAnimation(activo.withValues(alpha: 0.7)),
                  ),
                ),
              )
            : Icon(
                reproductor.estaReproduciendo
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: activo,
                size: r.subtitleSize + 18,
              ),
      ),
    );
  }
}