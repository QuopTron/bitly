import 'search_result.dart';

class TrackResult extends SearchResult {
  final String artist;
  final String album;
  final String coverUrl;

  const TrackResult({
    required super.id,
    required super.title,
    required super.source,
    required this.artist,
    required this.album,
    this.coverUrl = '',
    super.quality,
    super.duration,
  });

  @override
  List<Object?> get props =>
      [...super.props, artist, album, coverUrl];
}
