// ─────────────────────────────────────────────────────────────
// contenido_mi_espacio_canciones.dart — PART de
// contenido_mi_espacio.dart: vista de canciones de Mi Espacio —
// lista de TarjetaTrack con like, descarga, borrar, info, más y
// compartir. Resuelve la carátula priorizando la local de la
// descarga, la del like y la del lote que contiene al track, y
// reproduce con contexto desde la cola.
// Se conecta con: contenido_mi_espacio.dart (misma library) +
// tarjeta_track + cubits (vía callbacks) + share_plus.
// Parte del flujo: Home → Mi Espacio → pestaña Canciones.
// ─────────────────────────────────────────────────────────────

part of 'contenido_mi_espacio.dart';

/// Lista de canciones amadas/descargadas con sus acciones.
Widget _vistaCanciones(
    ContenidoMiEspacio c, BuildContext context, Responsive r) {
  final likeCubit = context.read<CubitLikes>();
  final dlCubit = context.read<CubitDescargas>();
  final feedItems =
      c.items
          .map(
            (s) => ItemFeed(
              id: s.idReal,
              type: 'track',
              name: s.titulo,
              artists: s.subtitulo,
              coverUrl: s.coverUrl,
              source: s.fuente.isNotEmpty ? s.fuente : null,
            ),
          )
          .toList();

  return ListView(
    padding: EdgeInsets.fromLTRB(
      r.spacingS,
      r.spacingS,
      r.spacingS,
      r.spacingS + r.val(120, 100, 150),
    ),
    children: feedItems.asMap().entries.map((entry) {
      final feedItem = entry.value;
      final s = c.items[entry.key];
      final id = 'track_${normalizarIdTrack(feedItem.id)}_${feedItem.source ?? ''}';
      // Carátula local de la descarga → like → lote dueño → URL remota.
      final caratulaDescarga =
          dlCubit.caratulaTrackLocal(feedItem.id, feedItem.source ?? '');
      final caratulaLike = likeCubit.caratulaLocalPara(feedItem);
      String? caratulaLote;
      if (caratulaDescarga == null &&
          caratulaLike == null &&
          feedItem.coverUrl == null) {
        final normId = normalizarIdTrack(feedItem.id);
        for (final bKey in dlCubit.state.descargas.keys) {
          if (!bKey.startsWith('album_') && !bKey.startsWith('playlist_')) {
            continue;
          }
          if (dlCubit.state.descargas[bKey]?.estado !=
              EstadoDescarga.completado) {
            continue;
          }
          final bc = dlCubit.caratulaLotePara(bKey);
          if (bc.isEmpty) continue;
          for (final bt in dlCubit.idsLotePara(bKey)) {
            if (normalizarIdTrack(bt).contains(normId) ||
                bt.contains(normId)) {
              caratulaLote = bc;
              break;
            }
          }
          if (caratulaLote != null) break;
        }
      }
      final caratulaResuelta =
          caratulaDescarga ?? caratulaLike ?? caratulaLote ?? feedItem.coverUrl;
      final esAmado = c.idsAmados.any(
        (rawId) => normalizarIdTrack(rawId) == normalizarIdTrack(feedItem.id),
      );
      final estadoDescarga = _estadoTrackPara(c, feedItem, id);
      final feedItemsParaPlay = feedItems;

      return Padding(
        key: ValueKey(
          'track_${normalizarIdTrack(feedItem.id)}_${feedItem.source ?? ''}',
        ),
        padding: EdgeInsets.only(bottom: r.spacingXS),
        child: TarjetaTrack(
          titulo: feedItem.name,
          subtitulo: feedItem.artists ?? '',
          coverUrl: caratulaResuelta,
          readyKey: normalizarIdTrack(feedItem.id),
          esAmado: esAmado,
          onLike: () {
            if (esAmado) {
              c.onQuitarLike(s);
            } else {
              c.onLike?.call(s);
            }
          },
          estadoDescarga: estadoDescarga,
          // textScale 1.2 + info/más: mismas dimensiones y acciones que
          // Feed/Búsqueda para que la tarjeta se vea igual en toda la app.
          escalaTexto: 1.2,
          onTap: () => sl<CubitCola>().reproducirConContexto(
            feedItemsParaPlay,
            feedItem,
          ),
          onDescargar: () => c._abrirDescarga(context, s),
          onBorrar:
              dlCubit.estadoDescargaPara(id).estado ==
                      EstadoDescarga.completado
                  ? () => dlCubit.borrarTrackResuelto(
                      ItemFeed(
                        id: s.idReal,
                        type: 'track',
                        name: s.titulo,
                        artists: s.subtitulo,
                        source: s.fuente,
                      ),
                    )
                  : null,
          onInfo: () => mostrarInfoCancion(context, feedItem),
          onMas: () => mostrarAgregarA(context, feedItem),
          onCompartir: () => SharePlus.instance.share(ShareParams(
                text: '🎵 ${s.titulo} — ${s.subtitulo}',
              )),
        ),
      );
    }).toList(),
  );
}