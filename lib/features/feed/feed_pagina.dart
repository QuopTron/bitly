// ─────────────────────────────────────────────────────────────
// feed_pagina.dart — Página del feed de inicio: lógica compartida
// (fuentes con contenido del backend, acciones de ítem globalizadas
// en AccionesItem) y el selector de variante móvil/escritorio. La
// cabecera y el cuerpo (con selectores de like/descargas) se arman
// en feed_pagina_widgets.dart y los helpers en
// feed_pagina_helpers.dart — cero duplicación entre variantes.
// Se conecta con: feed_bloc + cubit_like + cubit_descargas +
// cabecera_feed + contenido_feed + deteccion_plataforma.
// Parte del flujo: Home → pestaña Inicio (feed).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/cache/estado_descarga.dart';
import '../../core/cache/estado_like.dart';
import '../../core/modelos/item_feed.dart';
import '../../core/modelos/seccion_feed.dart';
import '../../estado/cubit_descargas.dart';
import '../../estado/cubit_like.dart';
import '../../shared/constantes/constantes_fuente.dart';
import '../../shared/tema/colores_app.dart';
import '../../shared/utilidades/acciones_item.dart';
import '../../shared/utilidades/deteccion_plataforma.dart';
import 'bloc/feed_bloc.dart';
import 'bloc/feed_estado.dart';
import 'bloc/feed_evento.dart';
import 'feed_escritorio.dart';
import 'feed_movil.dart';
import 'widgets/cabecera_feed.dart';
import 'widgets/contenido_feed.dart';

part 'feed_pagina_helpers.dart';
part 'feed_pagina_widgets.dart';

/// Página del feed con variante móvil/escritorio.
class PaginaFeed extends StatefulWidget {
  /// Navegación opcional al detalle (lo cablea el shell; null = inerte).
  final void Function(ItemFeed item)? onNavegarItem;

  const PaginaFeed({super.key, this.onNavegarItem});

  @override
  State<PaginaFeed> createState() => _PaginaFeedState();
}

class _PaginaFeedState extends State<PaginaFeed> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BlocFeed, EstadoFeed>(
      builder: (context, state) {
        final secciones = state.fuenteSeleccionada.isEmpty
            ? state.secciones
            : state.secciones
                .where((s) => s.source == state.fuenteSeleccionada)
                .toList();
        final tieneContenido =
            secciones.isNotEmpty && secciones.any((s) => s.items.isNotEmpty);

        final cabecera = _construirCabecera(this, state);
        final cuerpo = _construirCuerpo(
            this, state, secciones, tieneContenido);

        if (usarLayoutEscritorio(context)) {
          return FeedEscritorio(
              cabecera: cabecera, cuerpo: cuerpo);
        }
        return FeedMovil(cabecera: cabecera, cuerpo: cuerpo);
      },
    );
  }
}