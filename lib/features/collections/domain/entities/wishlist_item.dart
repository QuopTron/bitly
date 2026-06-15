class WishlistItem {
  final String id;
  final String trackName;
  final String artistName;
  final String? albumName;
  final String? spotifyId;
  final String? isrc;
  final DateTime addedAt;

  const WishlistItem({
    required this.id,
    required this.trackName,
    required this.artistName,
    this.albumName,
    this.spotifyId,
    this.isrc,
    required this.addedAt,
  });
}
