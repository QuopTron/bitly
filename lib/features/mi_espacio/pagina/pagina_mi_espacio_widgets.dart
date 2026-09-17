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
/// [hayReintentables] = hay descargas cortadas que se pueden reintentar (lotes
/// o canciones sueltas); [interrumpidas] = cuántas son, para el texto.
Widget _construirCabecera(
    _PaginaMiEspacioState st, Color onBg, bool hayReintentables, int interrumpidas) {
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
      if (hayReintentables) _bannerReintentar(st.context, onBg, interrumpidas),
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
