// ─────────────────────────────────────────────────────────────
// pagina_mi_espacio_build.dart — PART de pagina_mi_espacio.dart: el
// `build` de la página — arma la cabecera y el cuerpo, cuenta las
// descargas interrumpidas (y si hay algo reintentable, lote o canción
// suelta) y elige la variante móvil o de escritorio según la plataforma.
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
    // Cualquier descarga cortada es reintentable desde el banner: los lotes y
    // también las canciones sueltas (antes el banner solo aparecía con lotes,
    // así que una canción suelta en rojo no tenía botón de reintento).
    final hayReintentables = estadoDl.descargas.entries.any(
      (e) =>
          e.value.estado == EstadoDescarga.interrumpido &&
          !e.key.endsWith('_audio') &&
          !e.key.endsWith('_lyrics') &&
          !e.key.endsWith('_video'),
    );

    final cabecera =
        _construirCabecera(st, onBg, hayReintentables, interrumpidas);
    final cuerpo = _construirCuerpo(st, onBg);

    if (usarLayoutEscritorio(st.context)) {
      return MiEspacioEscritorio(cabecera: cabecera, cuerpo: cuerpo);
    }
    return MiEspacioMovil(cabecera: cabecera, cuerpo: cuerpo);
  
}
