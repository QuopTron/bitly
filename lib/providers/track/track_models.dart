class ArtistAlbum {
  final String id;
  final String name;
  final String releaseDate;
  final int totalTracks;
  final String? coverUrl;
  final String albumType;
  final String artists;
  final String? providerId;

  const ArtistAlbum({
    required this.id,
    required this.name,
    required this.releaseDate,
    required this.totalTracks,
    this.coverUrl,
    required this.albumType,
    required this.artists,
    this.providerId,
  });
}

class SearchArtist {
  final String id;
  final String name;
  final String? imageUrl;
  final int followers;
  final int popularity;

  const SearchArtist({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.followers,
    required this.popularity,
  });

  factory SearchArtist.fromJson(Map<String, dynamic> json) {
    return SearchArtist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? json['images']?.toString(),
      followers: json['followers'] as int? ?? 0,
      popularity: json['popularity'] as int? ?? 0,
    );
  }
}

class SearchAlbum {
  final String id;
  final String name;
  final String artists;
  final String? imageUrl;
  final String? releaseDate;
  final int totalTracks;
  final String albumType;

  const SearchAlbum({
    required this.id,
    required this.name,
    required this.artists,
    this.imageUrl,
    this.releaseDate,
    required this.totalTracks,
    required this.albumType,
  });

  factory SearchAlbum.fromJson(Map<String, dynamic> json) {
    return SearchAlbum(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      artists: json['artists']?.toString() ?? json['artist']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? json['images']?.toString(),
      releaseDate: json['release_date']?.toString(),
      totalTracks: json['total_tracks'] as int? ?? json['track_count'] as int? ?? 0,
      albumType: json['album_type']?.toString() ?? 'album',
    );
  }
}

class SearchPlaylist {
  final String id;
  final String name;
  final String owner;
  final String? imageUrl;
  final int totalTracks;

  const SearchPlaylist({
    required this.id,
    required this.name,
    required this.owner,
    this.imageUrl,
    required this.totalTracks,
  });

  factory SearchPlaylist.fromJson(Map<String, dynamic> json) {
    return SearchPlaylist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      owner: json['owner']?.toString() ?? json['username']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? json['images']?.toString(),
      totalTracks: json['total_tracks'] as int? ?? json['track_count'] as int? ?? 0,
    );
  }
}