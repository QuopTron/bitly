// ─────────────────────────────────────────────────────────────
// modelo_filtros_mi_espacio.dart — Modelo de filtro y orden de
// Mi Espacio: el enum ModoOrden (A-Z, Z-A, más escuchados,
// por artista, nuevos) y la clase inmutable FiltrosMiEspacio
// con copiarCon().
// Se conecta con: controles_orden_mi_espacio + aplicar_filtros.
// Parte del flujo: Home → Mi Espacio (filtros de la biblioteca).
// ─────────────────────────────────────────────────────────────

/// Modo de ordenamiento de la lista.
enum ModoOrden {
  az,
  azInvertido,
  masEscuchados,
  porArtista,
  nuevos,
}

/// Filtros activos para Mi Espacio.
class FiltrosMiEspacio {
  final ModoOrden modoOrden;
  final bool soloAmados;
  final bool soloDescargados;
  final bool soloConPlaylist;

  const FiltrosMiEspacio({
    this.modoOrden = ModoOrden.az,
    this.soloAmados = false,
    this.soloDescargados = false,
    this.soloConPlaylist = false,
  });

  FiltrosMiEspacio copiarCon({
    ModoOrden? modoOrden,
    bool? soloAmados,
    bool? soloDescargados,
    bool? soloConPlaylist,
  }) {
    return FiltrosMiEspacio(
      modoOrden: modoOrden ?? this.modoOrden,
      soloAmados: soloAmados ?? this.soloAmados,
      soloDescargados: soloDescargados ?? this.soloDescargados,
      soloConPlaylist: soloConPlaylist ?? this.soloConPlaylist,
    );
  }

  bool get hayFiltros =>
      soloAmados || soloDescargados || soloConPlaylist ||
      modoOrden != ModoOrden.az;
}
