// ─────────────────────────────────────────────────────────────
// hoja_playlist_acciones.dart — PART de hoja_playlist.dart: la lógica
// de la hoja — traer las canciones de la playlist que se edita, sumar
// canciones sin duplicar, quitar una, elegir la portada y guardar
// (nombre + portada + las canciones exactas, en orden).
// Se conecta con: hoja_playlist.dart (misma library) + editor_playlist
// + cubit_playlists + reproduccion_detalle_local + portada_playlist.
// Parte del flujo: Mi Espacio / detalle → playlists (crear y editar).
// ─────────────────────────────────────────────────────────────

part of 'hoja_playlist.dart';

/// Trae las canciones actuales de la playlist que se está editando.
Future<void> _cargarExistente(_HojaPlaylistState st) async {
  st._cargando = true;
  st.refrescar();
  final detalle = await sl<ReproduccionDetalleLocal>().getDetallePlaylistLocal(
    st.widget.playlistId!,
  );
  if (!st.mounted) return;
  if (detalle != null) {
    if (st._nombre.text.trim().isEmpty) st._nombre.text = detalle.name;
    st._portada ??= detalle.coverPath;
    st._canciones
      ..clear()
      ..addAll(detalle.tracks.map(_trackAItem));
  }
  st._cargando = false;
  st.refrescar();
}

/// Suma canciones sin duplicar (una canción ya en la lista no se repite).
void _agregarItems(_HojaPlaylistState st, Iterable<ItemFeed> items) {
  final ids = st._canciones.map((c) => c.id).toSet();
  for (final item in items) {
    if (item.id.isEmpty) continue;
    if (!ids.add(item.id)) continue;
    st._canciones.add(item);
  }
  st.refrescar();
}

/// Quita la canción de la posición [indice].
void _quitarCancion(_HojaPlaylistState st, int indice) {
  if (indice < 0 || indice >= st._canciones.length) return;
  st._canciones.removeAt(indice);
  st.refrescar();
}

/// Pide la foto de portada al dispositivo y la deja puesta.
Future<void> _elegirPortada(_HojaPlaylistState st) async {
  final titulo = AppLocalizations.of(st.context).setup.playlistChangeCover;
  final ruta = await elegirPortadaPlaylist(titulo: titulo);
  if (ruta == null || !st.mounted) return;
  st._portada = ruta;
  st.refrescar();
}

/// Guarda la playlist (nueva o editada) y cierra la hoja con su id.
Future<void> _guardarPlaylist(_HojaPlaylistState st) async {
  final loc = AppLocalizations.of(st.context);
  final nombre = st._nombre.text.trim();
  if (nombre.isEmpty) {
    _avisar(st, loc.setup.playlistNameNeeded);
    return;
  }
  if (st._guardando) return;
  st._guardando = true;
  st.refrescar();

  final id = await sl<ServicioEditorPlaylist>().guardar(
    playlistId: st.widget.playlistId,
    nombre: nombre,
    portada: st._portada ?? _portadaDePrimeraCancion(st),
    items: List<ItemFeed>.unmodifiable(st._canciones),
  );
  if (!st.mounted) return;
  if (id == null) {
    st._guardando = false;
    st.refrescar();
    _avisar(st, loc.setup.playlistSaveFailed);
    return;
  }
  await sl<CubitPlaylists>().cargarPlaylists();
  if (!st.mounted) return;
  Navigator.pop(st.context, id);
}

/// Sin foto elegida, la playlist usa la carátula de su primera canción.
String _portadaDePrimeraCancion(_HojaPlaylistState st) =>
    st._canciones.isEmpty ? '' : (st._canciones.first.coverUrl ?? '');

/// Aviso breve dentro de la app.
void _avisar(_HojaPlaylistState st, String mensaje) {
  ScaffoldMessenger.of(st.context).showSnackBar(
    SnackBar(
      content: Text(mensaje),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Convierte una canción de la biblioteca local en item de la hoja.
ItemFeed _trackAItem(TrackDetalle t) => ItemFeed(
  id: t.trackId,
  type: 'track',
  name: t.name,
  artists: t.artistName,
  coverUrl: mejorCaratula(t.coverPath, t.coverUrl),
  source: t.provider,
  albumName: t.albumName,
  durationMs: t.durationMs,
  isrc: t.isrc,
);
