// ─────────────────────────────────────────────────────────────
// info_cancion_hoja.dart — PART de modal_info_cancion.dart:
// construye la hoja del modal de info de canción (carátula, título,
// artista, filas de datos y botón de compartir). El color lo aplica
// el wrapper de estilo.
// Se conecta con: modal_info_cancion.dart (misma library) +
// modal_info_cancion_widgets (_filaInfo/_botonCompartir).
// Parte del flujo: Reproductor → info de canción.
// ─────────────────────────────────────────────────────────────

part of 'modal_info_cancion.dart';

/// Arma el contenido visual de la hoja (sin el color ni el blur, que los
/// decide el wrapper de estilo).
Widget _construirHojaInfoCancion({
  required BuildContext context,
  required Responsive r,
  required Color onBg,
  required AppLocalizations loc,
  required ItemFeed item,
  required String duracion,
  required Color fondoModal,
}) {
  return Container(
    margin: EdgeInsets.only(top: r.spacingXL * 2),
    decoration: BoxDecoration(
      color: fondoModal,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: r.spacingM),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: onBg.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: r.spacingXL),
            if (item.coverUrl != null && item.coverUrl!.isNotEmpty)
              ImagenPortada(
                coverUrl: item.coverUrl,
                ancho: r.width * 0.5,
                alto: r.width * 0.5,
                radioBorde: 16,
                fallback: Container(
                  width: r.width * 0.5,
                  height: r.width * 0.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.music_note,
                      size: 48, color: Colors.white.withValues(alpha: 0.3)),
                ),
              ),
            SizedBox(height: r.spacingL),
            Text(item.name,
                style: TextStyle(
                    fontSize: r.subtitleSize + 2,
                    fontWeight: FontWeight.bold,
                    color: onBg),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            SizedBox(height: r.spacingXS),
            Text(item.artists ?? '',
                style: TextStyle(
                    fontSize: r.subtitleSize,
                    color: onBg.withValues(alpha: 0.6)),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            SizedBox(height: r.spacingL),
            _filaInfo(r, onBg, Icons.music_note, loc.setup.feedSubtitleTrack,
                item.name),
            if (item.albumName != null)
              _filaInfo(r, onBg, Icons.album, loc.setup.feedSubtitleAlbum,
                  item.albumName!),
            _filaInfo(r, onBg, Icons.timer_outlined, loc.setup.trackDuration,
                duracion),
            if (item.type != 'track')
              _filaInfo(r, onBg, Icons.category_outlined, loc.setup.trackType,
                  item.type),
            SizedBox(height: r.spacingL),
            _botonCompartir(context, r, onBg, item),
            SizedBox(height: r.spacingXL),
          ],
        ),
      ),
    ),
  );
}
