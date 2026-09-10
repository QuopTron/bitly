// ─────────────────────────────────────────────────────────────
// pagina_busqueda_widgets.dart — PART de pagina_busqueda.dart:
// construye las piezas compartidas de la vista — la barra de
// búsqueda con el selector de fuente dentro (reemplaza el icono),
// los chips de categoría y el cuerpo con los BlocSelectors de like
// y descargas. Ambas variantes (móvil/escritorio) reciben estas
// piezas ya armadas.
// Se conecta con: pagina_busqueda.dart (misma library) +
// barra_busqueda + acordeon_fuente + chips_tipo_busqueda +
// busqueda_cuerpo.
// Parte del flujo: búsqueda (piezas del layout).
// ─────────────────────────────────────────────────────────────

part of 'pagina_busqueda.dart';

/// Barra de búsqueda con el selector de fuente como prefijo.
Widget _construirBarra(_PaginaBusquedaState st, EstadoBusqueda state) {
  final esOscuro = Theme.of(st.context).brightness == Brightness.dark;
  final onBg = ColoresApp.enSuperficie(esOscuro);
  final colorBrillo =
      esOscuro ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;

  return BarraBusqueda(
    controlador: st._controlador,
    onTextoCambiado: (v) => _onTextoCambiado(st, v),
    onLimpiar: () => _limpiarBusqueda(st),
    hintTexto: _hintBusqueda(st, state),
    triggerFuente: AcordeonFuente(
      fuentes: _fuentesBusqueda(state),
      fuenteSeleccionada: st._fuente,
      onBg: onBg,
      colorBrillo: colorBrillo,
      onCambiada: (f) => _onFuenteCambiada(st, f),
    ),
  );
}

/// Chips de categoría de la fuente activa.
Widget _construirChips(_PaginaBusquedaState st, EstadoBusqueda state) {
  return ChipsTipoBusqueda(
    tipoSeleccionado: st._tipo,
    filtros: _filtrosPara(state, st._fuente),
    onTipoCambiado: (t) => _onTipoCambiado(st, t),
  );
}

/// Cuerpo con resultados/recientes/pegar URL y selectores de estado.
Widget _construirCuerpo(_PaginaBusquedaState st, EstadoBusqueda state,
    bool mostrarResultados, bool mostrarRecientes) {
  return CuerpoBusqueda(
    tipoSeleccionado: st._tipo,
    fuenteSeleccionada: st._fuente,
    resultados: state.resultados,
    cargando: st._buscando || state.cargando,
    haBuscado: state.haBuscado,
    error: state.error,
    mostrarResultados: mostrarResultados,
    mostrarRecientes: mostrarRecientes,
    busquedasRecientes: state.busquedasRecientes,
    onAlternarLike: (id, [item]) => _alternarLike(st, id, item),
    onIniciarDescarga: (item) => _iniciarDescarga(st, item),
    onBorrarTrack: (item) => _borrarTrack(st, item),
    onDescargaLote: (item) => _iniciarDescargaLote(st, item),
    onBorradoLote: (item) => _borradoLote(st, item),
    onExportarPlaylist: (item) => _exportarPlaylist(st, item),
    onMostrarInfo: _mostrarInfo,
    onMostrarMas: _mostrarMas,
    onNavegarItem: st.widget.onNavegarItem,
    onBusquedaTocada: (q) => _repetirBusqueda(st, q),
    onLimpiarRecientes: () => st.context
        .read<BlocBusqueda>()
        .add(const LimpiarBusquedasRecientes()),
    onQuitarReciente: (q) =>
        st.context.read<BlocBusqueda>().add(QuitarBusquedaReciente(q)),
  );
}