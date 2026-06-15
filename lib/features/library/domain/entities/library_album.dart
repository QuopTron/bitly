class LibraryAlbum {
  final String id;
  final String title;
  final String artist;
  final String? coverPath;
  final int trackCount;
  final int year;

  LibraryAlbum({
    required this.id,
    required this.title,
    required this.artist,
    this.coverPath,
    required this.trackCount,
    required this.year,
  });
}
