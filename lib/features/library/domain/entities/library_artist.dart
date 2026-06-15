class LibraryArtist {
  final String id;
  final String name;
  final String? imagePath;
  final int albumCount;
  final int trackCount;

  LibraryArtist({
    required this.id,
    required this.name,
    this.imagePath,
    required this.albumCount,
    required this.trackCount,
  });
}
