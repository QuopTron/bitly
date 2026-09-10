// ─────────────────────────────────────────────────────────────
// reproductor_pagina_letras.dart — PART de reproductor_pagina.dart:
// lógica de letras del NowPlaying — abre la hoja karaoke con las
// LRC precargadas cuando existen o las busca bajo demanda (con
// spinner en el botón), y el subtítulo secundario del track
// (\"Álbum  •  Fuente\").
// Se conecta con: reproductor_pagina.dart (misma library) +
// cubit_reproductor + cubit_cola + hoja de letras + l10n.
// Parte del flujo: reproductor (letras karaoke).
// ─────────────────────────────────────────────────────────────

part of 'reproductor_pagina.dart';

/// Abre la hoja de letras karaoke; usa la precargada o busca bajo demanda.
void _alternarLetras(_ReproductorPaginaState st, BuildContext ctx) {
  final cubit = sl<CubitReproductor>();
  final cola = sl<CubitCola>().state;
  if (!cola.tieneActual) return;
  final track = cola.actual!;

  void abrirHoja(String texto) {
    if (!ctx.mounted) return;
    mostrarHojaLetras(ctx, track: track, letras: texto);
  }

  final precargadas = cubit.letrasPrecargadas;
  if (precargadas != null && precargadas.isNotEmpty) {
    abrirHoja(precargadas);
    return;
  }
  // Nada precargado — rescatar las LRC bajo demanda.
  st._letrasCargando = true;
    st.repintar();
  cubit.obtenerLetrasBajoDemanda(track).then((texto) {
    if (!st.mounted) return;
    st._letrasCargando = false;
    st.repintar();
    if (texto != null && texto.isNotEmpty) {
      abrirHoja(texto);
    } else if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Sin letras para esta canción'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  });
}

/// Línea secundaria bajo el artista: \"Álbum  •  Fuente\".
String? _metaSubtitulo(ItemFeed track) {
  final partes = <String>[];
  if (track.albumName != null && track.albumName!.isNotEmpty) {
    partes.add(track.albumName!);
  }
  final src = _etiquetaFuente(track.source);
  if (src != null) partes.add(src);
  if (partes.isEmpty) return null;
  return partes.join('  •  ');
}

/// Nombre legible de la fuente (Deezer, Spotify, Tidal, etc.).
String? _etiquetaFuente(String? fuente) {
  if (fuente == null || fuente.isEmpty) return null;
  switch (fuente) {
    case 'deezer':
      return 'Deezer';
    case 'spotify-web':
    case 'spotify':
      return 'Spotify';
    case 'apple-music':
      return 'Apple Music';
    case 'ytmusic-spotiflac':
      return 'YTMusic';
    case 'qobuz-web':
      return 'Qobuz';
    case 'tidal-web':
      return 'Tidal';
    case 'soundcloud':
      return 'SoundCloud';
    case 'amazon':
      return 'Amazon Music';
    case 'pandora':
      return 'Pandora';
    case 'musicbrainz':
      return 'MusicBrainz';
    case 'youtube':
      return 'YouTube';
    default:
      return fuente
          .split(RegExp(r'[-_ ]'))
          .where((w) => w.isNotEmpty)
          .map((w) => w[0].toUpperCase() + w.substring(1))
          .join(' ');
  }
}