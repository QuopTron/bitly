// ─────────────────────────────────────────────────────────────
// hoja_playlist_lista.dart — PART de hoja_playlist.dart: la lista de
// canciones de la playlist (cargando, vacía o con filas) y cada fila
// con su botón para quitarla. El estado vacío vive en
// hoja_playlist_vacio.dart.
// Se conecta con: hoja_playlist.dart (misma library) + ImagenPortada.
// Parte del flujo: Mi Espacio / detalle → playlists (canciones).
// ─────────────────────────────────────────────────────────────

part of 'hoja_playlist.dart';

/// Lista de canciones de la playlist (o su estado vacío / de carga).
Widget _listaCanciones(
  _HojaPlaylistState st,
  Responsive r,
  AppLocalizations loc,
  Color onBg,
) {
  if (st._cargando) {
    return Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: onBg.withValues(alpha: 0.4),
        ),
      ),
    );
  }
  if (st._canciones.isEmpty) return _cancionesVacias(r, loc, onBg);
  return ListView.builder(
    padding: EdgeInsets.symmetric(vertical: r.spacingS),
    itemCount: st._canciones.length,
    itemBuilder: (_, i) => _filaCancion(st, r, onBg, loc, i),
  );
}

/// Una canción de la lista, con su botón para quitarla.
Widget _filaCancion(
  _HojaPlaylistState st,
  Responsive r,
  Color onBg,
  AppLocalizations loc,
  int indice,
) {
  final item = st._canciones[indice];
  return SizedBox(
    height: _altoFilaCancion(r),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingM + 6),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: ImagenPortada(
              coverUrl: item.coverUrl,
              rutaLocal: item.coverUrl,
              radioBorde: 8,
            ),
          ),
          SizedBox(width: r.spacingM),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.subtitleSize - 1,
                    fontWeight: FontWeight.w600,
                    color: onBg,
                  ),
                ),
                if (item.artists != null && item.artists!.isNotEmpty)
                  Text(
                    item.artists!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: r.footerSize,
                      color: onBg.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: loc.setup.playlistRemove,
            onPressed: () => _quitarCancion(st, indice),
            icon: Icon(
              Icons.close_rounded,
              size: r.subtitleSize + 2,
              color: onBg.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    ),
  );
}
