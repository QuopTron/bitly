class FavoriteAlbum {
  final String id;
  final String title;
  final String artist;
  final String? coverUrl;
  final DateTime addedAt;

  const FavoriteAlbum({
    required this.id,
    required this.title,
    required this.artist,
    this.coverUrl,
    required this.addedAt,
  });
}
