// ─────────────────────────────────────────────────────────────
// hoja_playlist_canciones.dart — PART de hoja_playlist.dart: los
// atajos que llenan la playlist de una vez (Me gustan / Descargadas,
// sin duplicar lo que ya está).
//
// Las canciones se piden a la BASE (FuentesPlaylist), no al estado en
// memoria: así el atajo funciona aunque el usuario abra esto apenas
// arranca la app, y trae TODO su historial de descargas (no las
// primeras 100). El chip muestra un spinner mientras lee y avisa si no
// había nada para sumar, en vez de quedarse mudo.
// Se conecta con: hoja_playlist.dart (misma library) + fuentes_playlist.
// Parte del flujo: Mi Espacio / detalle → playlists (canciones).
// ─────────────────────────────────────────────────────────────

part of '../base/hoja_playlist.dart';

/// Chips para sumar las canciones likeadas o descargadas de una vez.
Widget _atajosCanciones(
  _HojaPlaylistState st,
  Responsive r,
  AppLocalizations loc,
  Color onBg,
  bool esOscuro,
) {
  final brillo = esOscuro ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
  return Padding(
    padding: EdgeInsets.fromLTRB(r.spacingM + 6, 0, r.spacingM + 6, r.spacingM),
    child: Wrap(
      spacing: r.spacingS,
      runSpacing: r.spacingS,
      children: [
        _chipFuente(
          r,
          onBg,
          brillo,
          Icons.favorite_rounded,
          loc.setup.playlistAddLiked,
          st._fuenteCargando ? null : () => _agregarLikeadas(st),
        ),
        _chipFuente(
          r,
          onBg,
          brillo,
          Icons.download_rounded,
          loc.setup.playlistAddDownloaded,
          st._fuenteCargando ? null : () => _agregarDescargadas(st),
        ),
      ],
    ),
  );
}

/// Chip táctil de una fuente de canciones. Sin [onTap] queda el spinner.
Widget _chipFuente(
  Responsive r,
  Color onBg,
  Color brillo,
  IconData icono,
  String etiqueta,
  VoidCallback? onTap,
) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: r.spacingM,
          vertical: r.spacingS,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: brillo.withValues(alpha: 0.2)),
          color: brillo.withValues(alpha: 0.06),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onTap == null)
              SizedBox(
                width: r.footerSize + 1,
                height: r.footerSize + 1,
                child: CircularProgressIndicator(strokeWidth: 2, color: brillo),
              )
            else
              Icon(icono, size: r.footerSize + 1, color: brillo),
            SizedBox(width: 4),
            Text(
              etiqueta,
              style: TextStyle(
                fontSize: r.footerSize,
                color: onBg.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Suma las canciones likeadas a la playlist (sin repetir ninguna).
Future<void> _agregarLikeadas(_HojaPlaylistState st) =>
    _desdeFuente(st, (fuentes) => fuentes.likeadas(), likeadas: true);

/// Suma las canciones descargadas a la playlist (sin repetir ninguna).
Future<void> _agregarDescargadas(_HojaPlaylistState st) =>
    _desdeFuente(st, (fuentes) => fuentes.descargadas(), likeadas: false);

/// Trae una fuente de la base, la suma y avisa si no había nada.
Future<void> _desdeFuente(
  _HojaPlaylistState st,
  Future<List<ItemFeed>> Function(FuentesPlaylist) traer, {
  required bool likeadas,
}) async {
  if (st._fuenteCargando) return;
  st._fuenteCargando = true;
  st.refrescar();

  List<ItemFeed> items;
  try {
    items = await traer(sl<FuentesPlaylist>());
  } catch (e) {
    debugPrint('[Playlist] no se pudo leer la fuente: $e');
    items = const [];
  }
  if (!st.mounted) return;

  st._fuenteCargando = false;
  _agregarItems(st, items);
  // Solo se avisa cuando la fuente estaba VACÍA: si sumó canciones, la
  // lista ya lo muestra.
  if (items.isEmpty) {
    final loc = AppLocalizations.of(st.context);
    _avisar(
      st,
      likeadas ? loc.setup.playlistNoLiked : loc.setup.playlistNoDownloads,
    );
  }
}
