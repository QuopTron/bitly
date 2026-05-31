/// Modelos de datos para consultas y operaciones del historial de descargas.
/// [HistoryLookupRequest] encapsula los criterios de búsqueda (Spotify ID,
/// ISRC, track + artist) y [HistoryBatchLookupRequest] agrupa múltiples
/// solicitudes para operaciones por lotes.
library;

class HistoryLookupRequest {
  final String spotifyId;
  final String? isrc;
  final String trackName;
  final String artistName;

  const HistoryLookupRequest({
    required this.spotifyId,
    this.isrc,
    required this.trackName,
    required this.artistName,
  });

  String get lookupKey => '${trackName.toLowerCase()}|${artistName.toLowerCase()}';
}

class HistoryBatchLookupRequest {
  final List<HistoryLookupRequest> tracks;
  const HistoryBatchLookupRequest(this.tracks);

  @override
  bool operator ==(Object other) =>
      other is HistoryBatchLookupRequest && _listEquals(tracks, other.tracks);

  @override
  int get hashCode => Object.hashAll(tracks);

  static bool _listEquals(List<HistoryLookupRequest> a, List<HistoryLookupRequest> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
