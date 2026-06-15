class LibraryTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int duration;
  final int fileSize;
  final String format;
  final DateTime addedAt;
  final String? coverPath;

  LibraryTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.fileSize,
    required this.format,
    required this.addedAt,
    this.coverPath,
  });
}
