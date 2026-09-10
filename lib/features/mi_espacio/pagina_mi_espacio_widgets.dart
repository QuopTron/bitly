// ─────────────────────────────────────────────────────────────
// pagina_mi_espacio_widgets.dart — PART de pagina_mi_espacio.dart:
// construye la cabecera (perfil + banner de interrupciones) y el
// cuerpo (pestañas + contenido en ContenedorVidrio con pull-to-
// refresh) de Mi Espacio. El build de la página solo calcula los
// datos y delega aquí para mantener las variantes livianas.
// Se conecta con: pagina_mi_espacio.dart (misma library) +
// perfil_mi_espacio + pestanas_mi_espacio + contenido_mi_espacio.
// Parte del flujo: Home → Mi Espacio (piezas del layout).
// ─────────────────────────────────────────────────────────────

part of 'pagina_mi_espacio.dart';

/// Cabecera de Mi Espacio: perfil + banner de descargas.
Widget _construirCabecera(
    _PaginaMiEspacioState st, Color onBg, bool hayLotes, int interrumpidas) {
  final estadoLike = st.context.watch<CubitLikes>().state;
  final stats = st.context.watch<CubitPlaylists>().state.stats;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PerfilMiEspacio(
        username: st._username,
        cancionesAmadas: contarTracks(
          estadoLike,
          cubitDescargas: st.context.read<CubitDescargas>(),
        ),
        playlistsCount: st._playlists.length,
        descargadosCount: _conteoCompletados(st),
        nivel: stats?.nivel ?? 0,
        progresoNivel: stats?.progreso ?? 0.0,
        siguienteNivel: stats?.siguienteNivel ?? 1,
        onBg: onBg,
        colorBrillo: onBg,
        onTemaCambiado: (v) => _onTemaCambiado(st, v),
        onIdiomaCambiado: () => _onIdiomaCambiado(st),
      ),
      SizedBox(height: 12),
      if (hayLotes) _bannerReintentar(st.context, onBg, interrumpidas),
    ],
  );
}

/// Conteo real de descargas completadas (sin subtareas _audio/_lyrics/_video).
int _conteoCompletados(_PaginaMiEspacioState st) {
  final estadoDl = st.context.watch<CubitDescargas>().state;
  return estadoDl.descargas.entries
      .where(
        (e) =>
            e.value.estado == EstadoDescarga.completado &&
            !e.key.endsWith('_audio') &&
            !e.key.endsWith('_lyrics') &&
            !e.key.endsWith('_video'),
      )
      .length;
}

/// Cuerpo de Mi Espacio: pestañas + contenido con refresh.
Widget _construirCuerpo(_PaginaMiEspacioState st, Color onBg) {
  final estadoLike = st.context.watch<CubitLikes>().state;
  final estadoDl = st.context.watch<CubitDescargas>().state;
  final loc = AppLocalizations.of(st.context);

  return Expanded(
    child: RefreshIndicator(
      onRefresh: () async {
        final likes = st.context.read<CubitLikes>();
        final descargas = st.context.read<CubitDescargas>();
        final playlists = st.context.read<CubitPlaylists>();
        await likes.inicializar();
        await descargas.initialize();
        await playlists.inicializar();
        await st._recargarPlaylists();
      },
      color: onBg,
      child: ContenedorVidrio(
        borderRadius: 16,
        borderColor: onBg.withValues(alpha: 0.06),
        bgColor: onBg.withValues(alpha: 0.02),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BarraPestanasMiEspacio(
              pestanaSeleccionada: st._pestanaSeleccionada,
              onCambioPestana: st._onCambioPestana,
              onBg: onBg,
              colorBrillo: onBg,
            ),
            SizedBox(height: 8),
            Expanded(
              child: ContenidoMiEspacio(
                cargando: st._cargando,
                items: itemsParaPestana(
                  estadoLike,
                  st._pestanaSeleccionada,
                  st._playlists,
                  cubitDescargas: st.context.read<CubitDescargas>(),
                ),
                pestanaSeleccionada: st._pestanaSeleccionada,
                mensajeVacio: mensajeVacio(loc, st._pestanaSeleccionada),
                idsAmados: estadoLike.todosAmados.keys.toSet(),
                estadosDescarga: estadoDl.descargas.map(
                  (k, v) => MapEntry(k, v.estado),
                ),
                huellasDescargadas: estadoDl.huellasDescargadas,
                contadoresReproduccion: st._contadoresReproduccion,
                onQuitarLike: (item) => quitarLikeItem(
                  item,
                  st.context,
                  st._pestanaSeleccionada,
                ),
                onLike: (item) => _onLike(st, item),
                onItemTap: (item) => st._onItemTap(item),
                onCreatePlaylist: () => _onCrearPlaylist(st),
                onCreateDesdeAmados: () => _onCrearPlaylistDesdeAmados(st),
                onCreateDesdeDescargados:
                    () => _onCrearPlaylistDesdeDescargados(st),
                onDescargaLote: (item) => _onDescargaLote(st, item),
                onBorrarLote: (item) => _onBorrarLote(st, item),
                onReintentarLote: (item) => _onReintentarLote(st, item),
                onExportarPlaylist: (item) => _onExportarPlaylist(st, item),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}