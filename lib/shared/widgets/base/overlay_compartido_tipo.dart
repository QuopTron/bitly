// ─────────────────────────────────────────────────────────────
// overlay_compartido_tipo.dart — PART de
// overlay_compartido_contenido.dart: qué icono y qué etiqueta le
// tocan a cada tipo compartido (canción, álbum, artista, playlist).
//
// La etiqueta sale del l10n, así el badge dice "CANCIÓN" en español y
// "TRACK" en inglés sin textos sueltos por el código.
//
// Se conecta con: overlay_compartido_contenido.dart (misma library).
// Parte del flujo: enlace compartido → carta → reproducir/encolar.
// ─────────────────────────────────────────────────────────────

part of 'overlay_compartido_contenido.dart';

/// Icono del tipo compartido.
IconData _iconoTipo(OverlayCompartidoContenido w) {
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

/// Etiqueta traducida del tipo compartido.
String _etiquetaTipo(OverlayCompartidoContenido w, StringsSetup l) {
  switch (w.type) {
    case 'album':
      return l.feedSubtitleAlbum.toUpperCase();
    case 'artist':
      return l.miSpaceArtist.toUpperCase();
    case 'playlist':
      return l.miSpacePlaylist.toUpperCase();
    default:
      return l.feedSubtitleTrack.toUpperCase();
  }
}
