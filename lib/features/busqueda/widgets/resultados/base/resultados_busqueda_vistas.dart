// ─────────────────────────────────────────────────────────────
// resultados_busqueda_vistas.dart — PART de
// resultados_busqueda.dart: vistas agrupadas de los resultados —
// por categoría (sin chip activo) y por fuente (fuente "Todas"),
// más la grilla de categoría única con su título. Cada agrupación
// arma las secciones con sus cabeceras y delega las tarjetas en
// los parts hermanos (secciones/tarjetas).
// Se conecta con: resultados_busqueda.dart (misma library) +
// tarjeta_track + tarjeta_grilla + l10n.
// Parte del flujo: búsqueda (resultados agrupados).
// ─────────────────────────────────────────────────────────────

part of 'resultados_busqueda.dart';

/// Vista agrupada por categoría (sin chip activo), como SpotiFLAC.
Widget _vistaAgrupadaPorCategoria(
  CuerpoResultadosBusqueda cuerpo,
  BuildContext context,
  Responsive r,
  Color colorBrillo,
  Color onBg,
  AppLocalizations loc,
) {
  final agrupado = <String, List<ItemFeed>>{
    'tracks': [],
    'artists': [],
    'albums': [],
    'playlists': [],
  };
  for (final it in cuerpo.resultados) {
    final cat = _categoriaDe(it.type);
    if (agrupado[cat] != null) agrupado[cat]!.add(it);
  }
  const orden = ['tracks', 'artists', 'albums', 'playlists'];
  final slivers = <Widget>[];
  for (final cat in orden) {
    final items = agrupado[cat]!;
    if (items.isEmpty) continue;
    slivers.add(
      SliverToBoxAdapter(
        child: _cabeceraSeccion(
          context,
          cat,
          items.length,
          r,
          colorBrillo,
          onBg,
        ),
      ),
    );
    if (cat == 'tracks') {
      slivers.add(_sliverTracks(cuerpo, context, items));
    } else {
      slivers.addAll(
        _seccionGrilla(
          cuerpo,
          context,
          r,
          items,
          colorBrillo: colorBrillo,
          onBg: onBg,
          titulo: null,
        ),
      );
    }
  }
  if (slivers.isEmpty) {
    return _centroSinResultados(loc, r, onBg);
  }
  return _listado(context, r, slivers);
}

/// Vista agrupada por fuente (fuente "Todas"): cada extensión en su sección.
Widget _vistaAgrupadaPorFuente(
  CuerpoResultadosBusqueda cuerpo,
  BuildContext context,
  Responsive r,
  Color colorBrillo,
  Color onBg,
  AppLocalizations loc,
) {
  final porFuente = <String, List<ItemFeed>>{};
  for (final it in cuerpo.resultados) {
    if (cuerpo.tipoSeleccionado != null &&
        _categoriaDe(it.type) != cuerpo.tipoSeleccionado) {
      continue;
    }
    final src = it.source ?? 'unknown';
    (porFuente[src] ??= []).add(it);
  }
  final slivers = <Widget>[];
  for (final entry in porFuente.entries) {
    if (entry.value.isEmpty) continue;
    slivers.add(
      SliverToBoxAdapter(
        child: _cabeceraFuente(
          context,
          entry.key,
          entry.value.length,
          r,
          colorBrillo,
          onBg,
        ),
      ),
    );
    if (cuerpo.tipoSeleccionado == 'tracks') {
      slivers.add(_sliverTracks(cuerpo, context, entry.value));
    } else {
      slivers.addAll(
        _seccionGrilla(
          cuerpo,
          context,
          r,
          entry.value,
          colorBrillo: colorBrillo,
          onBg: onBg,
          titulo: null,
        ),
      );
    }
  }
  if (slivers.isEmpty) {
    return _centroSinResultados(loc, r, onBg);
  }
  return _listado(context, r, slivers);
}

/// Grilla de una sola categoría con su título.
Widget _grillaUnica(
  CuerpoResultadosBusqueda cuerpo,
  BuildContext context,
  Responsive r,
  Color colorBrillo,
  Color onBg,
  AppLocalizations loc,
  List<ItemFeed> items,
) {
  return _listado(context, r, [
    ..._seccionGrilla(
      cuerpo,
      context,
      r,
      items,
      colorBrillo: colorBrillo,
      onBg: onBg,
      titulo: _etiquetaCategoria(loc, cuerpo.tipoSeleccionado!),
    ),
  ]);
}

/// Mensaje centrado de "sin resultados" (compartido por las vistas).
Widget _centroSinResultados(AppLocalizations loc, Responsive r, Color onBg) {
  return Center(
    child: Text(
      loc.setup.noResults,
      style: TextStyle(
        fontSize: r.subtitleSize,
        color: onBg.withValues(alpha: 0.4),
      ),
    ),
  );
}
