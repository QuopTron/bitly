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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../../app/inyeccion/inyeccion.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../core/cache/estado/estado_cola.dart';
import '../../../../../core/modelos/feed/item_feed.dart';
import '../../../../../core/modelos/usuario/preferencias/preferencias_estilo.dart';
import '../../../../../estado/cola/cubit_cola.dart';
import '../../../../../estado/like/base/cubit_like.dart';
import '../../../../../shared/tema/colores_app.dart';
import '../../../../../shared/tema/especificaciones/especificaciones_plataforma.dart';
import '../../../../../shared/utilidades/formato/comun/formato/estilo_helper.dart';
import '../../../../../shared/utilidades/interaccion/haptico.dart';
import '../../../../../shared/utilidades/modales/mostrar_modal.dart';
import '../../../../../shared/utilidades/portada/paleta/paleta_portada.dart';
import '../../../../../shared/utilidades/plataforma/pantalla/insets_sistema.dart';
import '../../../../../shared/utilidades/plataforma/responsive.dart';
import '../../../../../shared/widgets/tarjetas/portada/imagen_portada.dart';
import '../../../video/textura_video_fondo.dart';
import '../../../../../shared/widgets/fondos/ambiente/atenuado_por_nivel.dart';
import '../../../../../shared/widgets/vidrio/base/fondo_reactivo_portada.dart';

part 'modal_cola_hoja.dart';
part '../piezas/modal_cola_piezas.dart';
part 'modal_cola_vacio.dart';
part '../../fila/modal_cola_fila.dart';
part '../../fila/modal_cola_fila_piezas.dart';
part '../piezas/modal_cola_chip.dart';
part '../../fondo/modal_cola_fondo.dart';
part '../../fondo/velo_cola_estilo_state.dart';

/// Abre el modal de la cola con el track actual resaltado.
///
/// [mostrarVideo]/[videoController] reflejan el estado portada↔video del
/// reproductor completo para que la cola nunca se vea como un panel gris.
void mostrarModalCola(
  BuildContext context, {
  bool mostrarVideo = false,
  VideoController? videoController,
}) {
  mostrarHoja<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder:
        (_) => MultiBlocProvider(
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
