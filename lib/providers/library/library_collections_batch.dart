import 'package:bitly/models/track.dart';
import 'library_collections_entries.dart';

class PlaylistAddBatchResult {
  final int addedCount;
  final int alreadyInPlaylistCount;
  const PlaylistAddBatchResult({required this.addedCount, required this.alreadyInPlaylistCount});
}

class PlaylistPickerSummaryRequest {
  final List<String> trackKeys;
  PlaylistPickerSummaryRequest({required this.trackKeys});
  factory PlaylistPickerSummaryRequest.fromTracks(List<Track> tracks) =>
      PlaylistPickerSummaryRequest(trackKeys: tracks.map((t) => trackCollectionKey(t)).toList());
}

class PlaylistPickerSummary {
  final String id;
  final String name;
  final String? coverImagePath;
  final String? previewCover;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int trackCount;
  final bool containsAllRequestedTracks;
  const PlaylistPickerSummary({
    required this.id, required this.name, this.coverImagePath, this.previewCover,
    required this.createdAt, required this.updatedAt, required this.trackCount,
    required this.containsAllRequestedTracks,
  });
}
