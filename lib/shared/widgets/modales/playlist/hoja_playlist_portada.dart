// ─────────────────────────────────────────────────────────────
// hoja_playlist_portada.dart — PART de hoja_playlist.dart: la
// portada de la playlist dentro de la hoja. Se ve la foto elegida
// (o un marcador) con una insignia de cámara; al tocarla se abre el
// explorador de imágenes del dispositivo.
// Se conecta con: hoja_playlist.dart (misma library) + ImagenPortada
// + portada_playlist.
// Parte del flujo: Mi Espacio / detalle → playlists (portada).
// ─────────────────────────────────────────────────────────────

part of 'hoja_playlist.dart';

/// Portada tocable de la playlist.
Widget _selectorPortada(
  _HojaPlaylistState st,
  Responsive r,
  Color onBg,
  bool esOscuro,
) {
  final brillo = esOscuro ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
  final lado = r.val(92, 72, 120);
  final portada = st._portada ?? '';
  final loc = AppLocalizations.of(st.context);

  return Semantics(
    button: true,
    label: loc.setup.playlistChangeCover,
    child: GestureDetector(
      // Key para las pruebas: tocar la portada abre el explorador.
      key: const Key('playlistCoverPicker'),
      onTap: () => _elegirPortada(st),
      child: SizedBox(
        width: lado,
        height: lado,
        child: Stack(
          children: [
            Positioned.fill(
              child:
                  portada.isEmpty
                      ? Container(
                        decoration: BoxDecoration(
                          color: onBg.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: onBg.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Icon(
                          Icons.music_note_rounded,
                          color: onBg.withValues(alpha: 0.35),
                          size: lado * 0.3,
                        ),
                      )
                      : ImagenPortada(
                        coverUrl: portada,
                        rutaLocal: portada,
                        radioBorde: 16,
                        ancho: lado,
                        alto: lado,
                      ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: brillo,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ColoresApp.fondo(esOscuro),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
