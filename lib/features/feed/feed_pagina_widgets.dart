// ─────────────────────────────────────────────────────────────
// feed_pagina_widgets.dart — PART de feed_pagina.dart: construye
// las piezas compartidas del feed — la cabecera (saludo + selector
// de fuente) y el cuerpo con los selectores de like (huellas
// amadas) y descargas (snapshot con igualdad de valor). Ambas
// variantes (móvil/escritorio) reciben estas piezas ya armadas.
// Se conecta con: feed_pagina.dart (misma library) + cabecera_feed
// + contenido_feed + cubit_like + cubit_descargas.
// Parte del flujo: feed de inicio (piezas del layout).
// ─────────────────────────────────────────────────────────────

part of 'feed_pagina.dart';

/// Cabecera del feed (saludo + username + selector de fuente).
Widget _construirCabecera(_PaginaFeedState st, EstadoFeed state) {
  final esOscuro = Theme.of(st.context).brightness == Brightness.dark;
  final onBg = ColoresApp.enSuperficie(esOscuro);
  final colorBrillo =
      esOscuro ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;

  return CabeceraFeed(
    onBg: onBg,
    colorBrillo: colorBrillo,
    fuentes: _fuentesDisponibles(st),
  );
}

/// Cuerpo del feed con selectores de like y descargas.
Widget _construirCuerpo(_PaginaFeedState st, EstadoFeed state,
    List<SeccionFeed> secciones, bool tieneContenido) {
  final esOscuro = Theme.of(st.context).brightness == Brightness.dark;
  final onBg = ColoresApp.enSuperficie(esOscuro);
  final colorBrillo =
      esOscuro ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;

  return BlocBuilder<CubitLikes, EstadoLikes>(
    buildWhen: (prev, next) =>
        prev.huellasAmadas != next.huellasAmadas,
    builder: (context, estadoLike) {
      return BlocSelector<CubitDescargas, EstadoCubitDescargas,
          SnapshotDescargasFeed>(
        selector: (dl) => SnapshotDescargasFeed(
          dl.descargas.map((k, v) => MapEntry(k, v.estado)),
          dl.huellasDescargadas,
        ),
        builder: (context, snap) {
          return ContenidoFeed(
            onBg: onBg,
            colorBrillo: colorBrillo,
            secciones: secciones,
            tieneContenido: tieneContenido,
            cargando: state.cargando,
            nombreFuenteActual: _nombreFuenteActual(st),
            idsAmados: estadoLike.huellasAmadas,
            estadosDescarga: snap.estados,
            huellasDescargadas: snap.huellas,
            onAlternarLike: (id, [item]) => _alternarLike(st, id, item),
            onIniciarDescarga: (item) => _iniciarDescarga(st, item),
            onBorrarTrack: (item) => _borrarTrack(st, item),
            onDescargaLote: (item) => _iniciarDescargaLote(st, item),
            onBorradoLote: (item) => _borradoLote(st, item),
            onExportarPlaylist: (item) => _exportarPlaylist(st, item),
            onMostrarInfo: _mostrarInfo,
            onMostrarMas: _mostrarMas,
            onNavegarItem: st.widget.onNavegarItem ?? (_) {},
            onRefrescar: () =>
                st.context.read<BlocFeed>().add(const CargarFeed()),
          );
        },
      );
    },
  );
}