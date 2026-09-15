// ─────────────────────────────────────────────────────────────
// pagina_mi_espacio_cuerpo.dart — PART de pagina_mi_espacio.dart:
// cuerpo de la página: fila superior (pestañas + toggle de búsqueda)
// más el contenido con refresco. La búsqueda solo aparece en la
// pestaña Canciones, desplegada como acordeón animado bajo la fila
// superior (el toggle vive arriba porque el miniplayer tapa abajo).
// Se conecta con: pestanas_mi_espacio + barra_busqueda_mi_espacio +
// boton_busqueda + contenido_mi_espacio.
// Parte del flujo: Home → Mi Espacio.
// ─────────────────────────────────────────────────────────────

part of 'pagina_mi_espacio.dart';

/// Cuerpo de Mi Espacio: pestañas + toggle de búsqueda (acordeón de
/// búsqueda y filtros solo en Canciones) y el contenido con refresco.
Widget _construirCuerpo(_PaginaMiEspacioState st, Color onBg) {
  final estadoLike = st.context.watch<CubitLikes>().state;
  final estadoDl = st.context.watch<CubitDescargas>().state;
  final loc = AppLocalizations.of(st.context);
  final esCanciones = st._pestanaSeleccionada == 0;
  final busquedaVisible = esCanciones && st._mostrarBusqueda;
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
            // Fila superior: pestañas a la izquierda, toggle de búsqueda
            // a la derecha (fijo arriba para que no lo tape el miniplayer).
            Row(
              children: [
                Expanded(
                  child: BarraPestanasMiEspacio(
                    pestanaSeleccionada: st._pestanaSeleccionada,
                    onCambioPestana: st._onCambioPestana,
                    onBg: onBg,
                    colorBrillo: onBg,
                  ),
                ),
                if (esCanciones)
                  Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: _BotonBusquedaToggle(
                      activo: st._mostrarBusqueda,
                      onBg: onBg,
                      onTap: () => st._aplicar(() {
                        st._mostrarBusqueda = !st._mostrarBusqueda;
                        if (!st._mostrarBusqueda) st._textoBusqueda = '';
                      }),
                    ),
                  ),
              ],
            ),
            // Acordeón de búsqueda: solo Canciones, se despliega al togglear.
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: busquedaVisible
                    ? BarraBusquedaMiEspacio(
                        key: const ValueKey('busqueda'),
                        onBusquedaCambiada: st._onBusquedaCambiada,
                        onBg: onBg,
                        hintText: loc.setup.searchHint,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            // Filtros de orden: solo con la búsqueda desplegada.
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: busquedaVisible
                    ? ControlesOrdenMiEspacio(
                        key: const ValueKey('filtros'),
                        filtros: st._filtros,
                        onFiltrosCambiados: st._onFiltrosCambiados,
                        onBg: onBg,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            SizedBox(height: 2),
            Expanded(
              child: ContenidoMiEspacio(
                cargando: st._cargando,
                items: _aplicarBusquedaYFiltros(
                  itemsParaPestana(
                    estadoLike,
                    st._pestanaSeleccionada,
                    st._playlists,
                    cubitDescargas: st.context.read<CubitDescargas>(),
                  ),
                  esCanciones ? st._textoBusqueda : '',
                  st._filtros,
                  st,
                  estadoLike,
                ),
                pestanaSeleccionada: st._pestanaSeleccionada,
                mensajeVacio: _mensajeVacioConFiltros(
                  esCanciones ? st._textoBusqueda : '',
                  st._filtros,
                  loc,
                  st._pestanaSeleccionada,
                ),
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
