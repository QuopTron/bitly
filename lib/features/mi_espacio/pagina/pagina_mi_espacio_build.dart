// ─────────────────────────────────────────────────────────────
// pagina_mi_espacio_build.dart — PART de pagina_mi_espacio.dart: el
// `build` de la página — arma la cabecera y el cuerpo, cuenta las
// descargas interrumpidas (y si hay lotes reintentables) y elige la
// variante móvil o de escritorio según la plataforma.
// Se conecta con: pagina_mi_espacio.dart (misma library) +
// mi_espacio_movil / mi_espacio_escritorio + cubit de descargas.
// Parte del flujo: Home → Mi Espacio.
// ─────────────────────────────────────────────────────────────

part of 'pagina_mi_espacio.dart';

Widget _construirPaginaMiEspacio(_PaginaMiEspacioState st) {
    final esOscuro = Theme.of(st.context).brightness == Brightness.dark;
    final onBg = esOscuro ? Colors.white : Colors.black;

    final estadoDl = st.context.watch<CubitDescargas>().state;
    final interrumpidas = estadoDl.descargas.values
        .where((d) => d.estado == EstadoDescarga.interrumpido)
        .length;
    final hayLotesReintentables = estadoDl.descargas.entries.any(
      (e) =>
          e.value.estado == EstadoDescarga.interrumpido &&
          (e.key.startsWith('album_') || e.key.startsWith('playlist_')),
    );

    final cabecera =
        _construirCabecera(st, onBg, hayLotesReintentables, interrumpidas);
    final cuerpo = _construirCuerpo(st, onBg);

    if (usarLayoutEscritorio(st.context)) {
      return MiEspacioEscritorio(cabecera: cabecera, cuerpo: cuerpo);
    }
    return MiEspacioMovil(cabecera: cabecera, cuerpo: cuerpo);
  
}
