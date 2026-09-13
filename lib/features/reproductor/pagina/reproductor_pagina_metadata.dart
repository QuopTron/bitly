// ─────────────────────────────────────────────────────────────
// reproductor_pagina_metadata.dart — PART de reproductor_pagina.dart:
// bloque de metadata del NowPlaying — título del track, artista y
// la línea secundaria (álbum • fuente). Se muestra centrado entre
// la portada y el seek bar.
// Se conecta con: reproductor_pagina.dart (misma library) + l10n.
// Parte del flujo: reproductor (metadata del NowPlaying).
// ─────────────────────────────────────────────────────────────

part of 'reproductor_pagina.dart';

/// Metadata del track: título, artista y línea secundaria (álbum • fuente).
Widget _metadataTrack(
  BuildContext context,
  Responsive r,
  ItemFeed track,
  Color activo,
) {
  final sub = _metaSubtitulo(track);
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        track.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: r.titleSize,
          fontWeight: FontWeight.bold,
          color: activo,
        ),
      ),
      SizedBox(height: r.spacingXS),
      Text(
        track.artists ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: r.subtitleSize,
          color: activo.withValues(alpha: 0.6),
        ),
      ),
      if (sub != null) ...[
        SizedBox(height: r.spacingXS),
        Text(
          sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: r.footerSize,
            letterSpacing: 0.2,
            color: activo.withValues(alpha: 0.4),
          ),
        ),
      ],
    ],
  );
}