// ─────────────────────────────────────────────────────────────
// cubit_like.dart — Cubit de favoritos/likes: carga todos los
// items amados (tracks/álbumes/artistas/playlists) de drift al
// arrancar, construye las huellas (incluyendo ISRC para matching
// cross-extensión) y resuelve la mejor carátula de un item.
// Las acciones de like/unlike viven en los parts:
//   - acciones_like.dart        (dar like + carátulas)
//   - acciones_like_quitar.dart (quitar like + sync de tracks)
// Se conecta con: CacheFavoritos + backend Go + DownloadCubit.
// Parte del flujo: botones de like y Mi Espacio → Favoritos.
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show protected;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app/inyeccion.dart' as di;
import '../core/backend_go/contrato_backend.dart';
import '../core/base_datos/app_database.dart';
import '../core/base_datos/daos/content_dao.dart';
import '../core/base_datos/daos/download_dao.dart';
import '../core/cache/cache_detalle.dart';
import '../core/cache/cache_favoritos.dart';
import '../core/cache/estado_like.dart';
import '../core/cache/reproduccion_sync.dart';
import '../core/modelos/detalle_album.dart';
import '../core/modelos/detalle_playlist.dart';
import '../core/modelos/item_feed.dart';
import '../core/servicios/huella_item.dart';
import '../core/servicios/utilidades_id.dart';
import 'cubit_descargas.dart';

part 'acciones_like.dart';
part 'acciones_like_quitar.dart';
part 'like_carga.dart';
part 'like_caratulas.dart';
part 'like_persistir.dart';
part 'like_quitar_por_id.dart';
part 'like_sync_tracks.dart';

class CubitLikes extends Cubit<EstadoLikes>
    with
        AccionesLike,
        AccionesLikePersistencia,
        LikeCarga,
        LikeCaratulas,
        AccionesLikeQuitar,
        LikeQuitarPorId,
        LikeSyncTracks {
  @override
  final BackendService backend;
  @override
  late final CacheFavoritos _fav;
  bool _inicializado = false;

  CubitLikes(this.backend) : super(const EstadoLikes()) {
    _fav = di.sl<CacheFavoritos>();
  }

  Future<void> inicializar() async {
    if (_inicializado) return;
    emit(state.copiarCon(cargando: true));
    try {
      await cargarFavoritos();
      _inicializado = true;
    } catch (e) {
      emit(state.copiarCon(cargando: false, error: e.toString()));
    }
  }

  bool estaAmado(ItemFeed item) {
    final fp = huellaItem(item);
    if (state.huellasAmadas.contains(fp)) return true;
    // Matching cross-extension: si el item trae ISRC (identificador compartido
    // entre todas las fuentes), el corazón se refleja aunque el fingerprint
    // por nombre/artista difiera (otra escritura, feat. distinto, etc.).
    final isrc = item.isrc;
    if (isrc != null && isrc.isNotEmpty) {
      return state.huellasAmadas.contains(huellaIsrc(isrc));
    }
    return false;
  }

  bool estaItemIdAmado(String id) => state.todosAmados.containsKey(id);

  DatosItemAmado? itemAmadoPorId(String id) => state.todosAmados[id];

  /// Resuelve la mejor carátula de un item, igual que resolveCoverFor en la
  /// versión anterior: 1) carátula local del like → 2) carátula local de la
  /// descarga (track o lote álbum/playlist) → 3) URL de red original.
  /// Usar SIEMPRE en vez de item.coverUrl para que los items likeados o
  /// descargados muestren su carátula local cacheada.
  String? caratulaLocalPara(ItemFeed item) {
    // 1. Carátula local del like (la más específica).
    final fp = huellaItem(item);
    final coincidente = state.todosAmados.values.where((v) {
      final feedItem = ItemFeed(
        id: v.id,
        type: v.type,
        name: v.name,
        artists: v.artists,
        coverUrl: v.coverUrl,
        albumName: v.albumName,
        durationMs: v.durationMs,
        isrc: v.isrc,
        source: v.source,
      );
      return huellaItem(feedItem) == fp;
    }).firstOrNull;
    final likeLocal = limpiarRutaCaratulaLocal(coincidente?.rutaCaratulaLocal);
    if (likeLocal != null && likeLocal.isNotEmpty) return likeLocal;

    // 2. Carátula local de la descarga (track o lote álbum/playlist).
    try {
      final descargas = di.sl<CubitDescargas>();
      if (item.type == 'track') {
        final dlCover = descargas.caratulaTrackLocal(
          item.id,
          item.source ?? '',
        );
        if (dlCover != null && dlCover.isNotEmpty) return dlCover;
      } else if (item.type == 'album' || item.type == 'playlist') {
        final batchKey = '${item.type}_${normalizarId(item.id)}_'
            '${item.source ?? ''}';
        final batchCover = descargas.caratulaLotePara(batchKey);
        if (batchCover.isNotEmpty) return batchCover;
      }
    } catch (_) {}

    // 3. Fallback a la URL de red original.
    return item.coverUrl;
  }

  List<DatosItemAmado> get tracks =>
      state.todosAmados.values.where((i) => i.type == 'track').toList();

  List<DatosItemAmado> get albums =>
      state.todosAmados.values.where((i) => i.type == 'album').toList();

  List<DatosItemAmado> get artists =>
      state.todosAmados.values.where((i) => i.type == 'artist').toList();

  int get tracksCount => tracks.length;
  int get albumsCount => albums.length;
  int get artistsCount => artists.length;
}