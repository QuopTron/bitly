// ─────────────────────────────────────────────────────────────
// modal_cola.dart — Modal de la cola de reproducción: track actual
// resaltado, siguientes tocables para saltar, reordenable con
// drag, fondo de carátula desenfocada (o el video visualizador en
// vivo) y chips de modo shuffle/repetición. Misma estética que el
// reproductor completo.
// Parts: _hoja, _fila, _chip, _fondo.
// Se conecta con: cubit_cola + cubit_like + cubit_reproductor +
// reproductor_video_fondo + paleta_portada.
// Parte del flujo: reproductor (modal de cola).
// ─────────────────────────────────────────────────────────────

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../app/inyeccion.dart';
import '../../core/cache/estado_cola.dart';
import '../../core/modelos/item_feed.dart';
import '../../core/modelos/perfil_rendimiento.dart';
import '../../estado/cubit_cola.dart';
import '../../estado/cubit_like.dart';
import '../../shared/tema/colores_app.dart';
import '../../shared/utilidades/haptico.dart';
import '../../shared/utilidades/paleta_portada.dart';
import '../../shared/utilidades/responsive.dart';
import '../../shared/widgets/imagen_portada.dart';
import 'textura_video_fondo.dart';

part 'modal_cola_hoja.dart';
part 'modal_cola_piezas.dart';
part 'modal_cola_fila.dart';
part 'modal_cola_fila_piezas.dart';
part 'modal_cola_chip.dart';
part 'modal_cola_fondo.dart';

/// Abre el modal de la cola con el track actual resaltado.
///
/// [mostrarVideo]/[videoController] reflejan el estado portada↔video del
/// reproductor completo para que la cola nunca se vea como un panel gris.
void mostrarModalCola(
  BuildContext context, {
  bool mostrarVideo = false,
  VideoController? videoController,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: false,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider<CubitCola>.value(value: sl<CubitCola>()),
        BlocProvider<CubitLikes>.value(value: sl<CubitLikes>()),
      ],
      child: _HojaCola(
        mostrarVideo: mostrarVideo,
        videoController: videoController,
      ),
    ),
  );
}