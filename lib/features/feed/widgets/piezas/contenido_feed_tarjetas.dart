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

part of '../base/contenido_feed.dart';

/// Fila del cuerpo del feed: cabecera de sección o canción.
///
/// Se guarda como DATO (no como widget) a propósito: así el `SliverList`
/// construye solo lo visible. Con widgets ya creados, el builder era un
/// detalle de forma — el trabajo ya estaba hecho.
class _FilaFeed {
  final String? tituloCabecera;
  final IconData? iconoCabecera;
  final ItemFeed? track;
  final List<ItemFeed>? contexto;

  const _FilaFeed.cabecera(this.tituloCabecera, this.iconoCabecera)
    : track = null,
      contexto = null;

  const _FilaFeed.track(this.track, this.contexto)
    : tituloCabecera = null,
      iconoCabecera = null;
}

/// Lista de filas de track de todas las secciones (máx 10 por sección).
///
/// Devuelve DATOS, no widgets: el `SliverList` de [_sliverTracks] es el que
/// construye cada tarjeta cuando toca (es decir, solo si entra en pantalla).
List<_FilaFeed> _filasTracks(ContenidoFeed c, BuildContext context) {
  final loc = AppLocalizations.of(context);
  final conTracks =
      c.secciones.where((s) => s.items.any((i) => i.type == 'track')).toList();
  final filas = <_FilaFeed>[];
  for (final seccion in conTracks) {
    final tracks =
        seccion.items.where((i) => i.type == 'track').take(10).toList();
    if (tracks.isEmpty) continue;
    // Cabecera de sección solo cuando hay más de una con tracks.
    if (seccion.title.isNotEmpty && conTracks.length > 1) {
      filas.add(
        _FilaFeed.cabecera(
          localizeFeedTitle(loc, seccion.title),
          Icons.wifi_tethering,
        ),
      );
    }
    for (final item in tracks) {
      filas.add(_FilaFeed.track(item, tracks));
    }
  }
  return filas;
}

/// Sliver perezoso con las filas de track del feed.
Widget _sliverTracks(
  ContenidoFeed c,
  BuildContext context,
  Responsive r,
) {
  final filas = _filasTracks(c, context);
  return SliverList.builder(
    itemCount: filas.length,
    itemBuilder: (context, index) {
      final fila = filas[index];
      final titulo = fila.tituloCabecera;
      if (titulo != null) {
        return _cabeceraSeccion(
          context,
          titulo: titulo,
          colorBrillo: c.colorBrillo,
          icono: fila.iconoCabecera ?? Icons.wifi_tethering,
        );
      }
      return _tarjetaTrackFeed(c, context, fila);
    },
  );
}

/// Tarjeta de una canción del feed (resuelve carátula/like/descarga acá, es
/// decir cuando la fila se monta).
Widget _tarjetaTrackFeed(
  ContenidoFeed c,
  BuildContext context,
  _FilaFeed fila,
) {
  final item = fila.track!;
  final tracks = fila.contexto!;
  final huella = huellaItem(item);
  final id = 'track_${normalizarIdTrack(item.id)}_${item.source}';
  final caratulaResuelta = context
      .read<CubitLikes>()
      .caratulaLocalPara(item);
  return TarjetaTrack(
    item: item,
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
    onTap: () => sl<CubitCola>().reproducirConContexto(tracks, item),
    onCompartir: () => ServicioCompartir.instance.compartir(item),
  );
}

/// Estado de descarga de un track: por clave de fuente, huella o ISRC.
EstadoDescarga _estadoDescargaTrack(
  ContenidoFeed c,
  String huella,
  String id,
  String? isrc,
) {
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
