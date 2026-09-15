// ─────────────────────────────────────────────────────────────
// overlay_compartido_tarjeta.dart — PART de
// overlay_compartido_contenido.dart: arte del overlay — portada con
// glow (o spinner mientras carga), badge con la etiqueta del tipo y
// los iconos/etiquetas según el tipo del ítem compartido.
// Se conecta con: overlay_compartido_contenido.dart (misma library).
// Parte del flujo: arranque / llegada de deep links.
// ─────────────────────────────────────────────────────────────

part of 'overlay_compartido_contenido.dart';

/// Portada del ítem compartido, con glow del color primario.
Widget _cubiertaOverlay(OverlayCompartidoContenido w, Responsive r, Color brillo) {
  if (w.cargando) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Center(child: CircularProgressIndicator(color: brillo, strokeWidth: 2)),
    );
  }
  return Container(
    width: 180,
    height: 180,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: brillo.withValues(alpha: 0.3),
          blurRadius: 40,
          spreadRadius: 8,
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: w.item?.coverUrl != null
          ? ImagenPortada(coverUrl: w.item!.coverUrl)
          : Container(
              color: brillo.withValues(alpha: 0.15),
              child: Icon(_iconoTipoOverlay(w), size: 64, color: brillo),
            ),
    ),
  );
}

/// Etiqueta del tipo de ítem compartido (Canción/Álbum/Playlist/Artista).
Widget _badgeTipoOverlay(OverlayCompartidoContenido w, Responsive r, Color brillo) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: brillo.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: brillo.withValues(alpha: 0.3)),
    ),
    child: Text(
      _etiquetaTipoOverlay(w),
      style: TextStyle(
        fontSize: r.footerSize - 1,
        color: brillo,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

IconData _iconoTipoOverlay(OverlayCompartidoContenido w) {
  switch (w.type) {
    case 'album':
      return Icons.album_rounded;
    case 'artist':
      return Icons.person_rounded;
    case 'playlist':
      return Icons.queue_music_rounded;
    default:
      return Icons.music_note_rounded;
  }
}

String _etiquetaTipoOverlay(OverlayCompartidoContenido w) {
  switch (w.type) {
    case 'album':
      return 'Álbum';
    case 'artist':
      return 'Artista';
    case 'playlist':
      return 'Playlist';
    default:
      return 'Canción';
  }
}
