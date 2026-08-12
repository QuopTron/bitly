import '../models/detail_models.dart';
import '../detail/load_utils.dart';
import '../../../injection.dart';
import '../../../backend/cache/detail_cache.dart';
import '../../../backend/rpc/backend_service.dart';

/// Fetches an album or playlist detail by [type]/[id]/[source].
///
/// [type] should be `'album'` or `'playlist'` — matches both `FeedItem.type`
/// (string) and `ItemType.name` (enum → string).
///
/// Returns `(name, tracks)` on success, or `null` if [type] is not supported
/// or the detail could not be fetched.
Future<(String name, List<DetailTrack> tracks)?> fetchDetail({
  required String type,
  required String id,
  required String source,
}) async {
  final cache = sl<DetailCache>();
  final backend = sl<BackendService>();
  if (type == 'album') {
    final detail = await loadDetailWithFallback(
      id: id,
      source: source,
      getLocal: (id) => cache.getAlbumDetail(id),
      fetchRemote: (id, src) => backend.fetchAlbumDetail(id, src),
      fromJson: AlbumDetail.fromJson,
    );
    if (detail == null) return null;
    return (detail.name, detail.tracks);
  }
  if (type == 'playlist') {
    final detail = await loadDetailWithFallback(
      id: id,
      source: source,
      getLocal: (id) => cache.getPlaylistDetail(id),
      fetchRemote: (id, src) => backend.fetchPlaylistDetail(id, src),
      fromJson: PlaylistDetail.fromJson,
    );
    if (detail == null) return null;
    return (detail.name, detail.tracks);
  }
  return null;
}


