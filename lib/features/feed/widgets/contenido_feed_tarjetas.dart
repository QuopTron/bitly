// ─────────────────────────────────────────────────────────────
// contenido_feed_tarjetas.dart — PART de contenido_feed.dart:
// construcción de las tarjetas del feed — lista de tracks
// (TarjetaTrack con like/descarga/compartir/info/más, máx 10 por
// sección) y grillas de álbumes/playlists/artistas (TarjetaGrilla
// con descarga por lote). Incluye el estado de descarga por clave
// de fuente o huella/ISRC y la cabecera de sección localizada.
// Se conecta con: contenido_feed.dart (misma library) + tarjeta_
// track + tarjeta_grilla + huella_item + cubits (vía callbacks del
// padre) + share_plus + feed_titles.
// Parte del flujo: feed de inicio (tarjetas del cuerpo).
// ─────────────────────────────────────────────────────────────

part of 'contenido_feed.dart';

/// Tarjetas de track de todas las secciones (máx 10 por sección).
List<Widget> _construirTracks(
    ContenidoFeed c, BuildContext context, Responsive r) {
  final loc = AppLocalizations.of(context);
  final conTracks =
      c.secciones.where((s) => s.items.any((i) => i.type == 'track')).toList();
  final widgets = <Widget>[];
  for (final seccion in conTracks) {
    final tracks = seccion.items.where((i) => i.type == 'track').take(10).toList();
    if (tracks.isEmpty) continue;
    // Cabecera de sección solo cuando hay más de una con tracks.
    if (seccion.title.isNotEmpty && conTracks.length > 1) {
      widgets.add(_cabeceraSeccion(
        context,
        titulo: localizeFeedTitle(loc, seccion.title),
        colorBrillo: c.colorBrillo,
        icono: Icons.wifi_tethering,
      ));
    }
    for (final item in tracks) {
      final huella = huellaItem(item);
      final id = 'track_${normalizarIdTrack(item.id)}_${item.source}';
      final caratulaResuelta =
          context.read<CubitLikes>().caratulaLocalPara(item);
      void play() => sl<CubitCola>().reproducirConContexto(tracks, item);
      widgets.add(TarjetaTrack(
        titulo: item.name,
        subtitulo: item.artists ?? '',
        coverUrl: caratulaResuelta,
        escalaTexto: 1.2,
        readyKey: normalizarIdTrack(item.id),
        esAmado: c.idsAmados.contains(huella),
        onLike: () => c.onAlternarLike(id, item),
        estadoDescarga: _estadoDescargaTrack(c, huella, id, item.isrc),
        onDescargar: () => c.onIniciarDescarga(item),
        onBorrar: c.onBorrarTrack != null ? () => c.onBorrarTrack!(item) : null,
        onInfo: () => c.onMostrarInfo(context, item),
        onMas: () => c.onMostrarMas(context, item),
        onTap: play,
        onCompartir: () => SharePlus.instance.share(ShareParams(
              text: item.albumName != null
                  ? '🎵 ${item.name} — ${item.artists ?? ''}\n💿 ${item.albumName}'
                  : '🎵 ${item.name} — ${item.artists ?? ''}',
            )),
      ));
    }
  }
  return widgets;
}

/// Estado de descarga de un track: por clave de fuente, huella o ISRC.
EstadoDescarga _estadoDescargaTrack(
    ContenidoFeed c, String huella, String id, String? isrc) {
  final s = c.estadosDescarga[id];
  if (s != null && s != EstadoDescarga.ninguno) return s;
  if (c.huellasDescargadas.contains(huella)) return EstadoDescarga.completado;
  if (isrc != null &&
      isrc.trim().isNotEmpty &&
      c.huellasDescargadas.contains(huellaIsrc(isrc))) {
    return EstadoDescarga.completado;
  }
  return EstadoDescarga.ninguno;
}

