import 'package:bitly/models/track.dart';
import 'library_collections_entries.dart';
import 'library_collections_batch.dart';

export 'library_collections_entries.dart';
export 'library_collections_batch.dart';

class UserPlaylistCollection {
  final String id;
  final String name;
  final String? coverImagePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CollectionTrackEntry> tracks;
  final Set<String> _trackKeys;
  UserPlaylistCollection({required this.id, required this.name, this.coverImagePath, required this.createdAt, required this.updatedAt, required this.tracks, Set<String>? trackKeys})
    : _trackKeys = trackKeys ?? tracks.map((entry) => entry.key).toSet();

  UserPlaylistCollection copyWith({String? id, String? name, String? Function()? coverImagePath, DateTime? createdAt, DateTime? updatedAt, List<CollectionTrackEntry>? tracks}) {
    final nextTracks = tracks ?? this.tracks;
    return UserPlaylistCollection(id: id ?? this.id, name: name ?? this.name, coverImagePath: coverImagePath != null ? coverImagePath() : this.coverImagePath, createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt, tracks: nextTracks, trackKeys: identical(nextTracks, this.tracks) ? _trackKeys : null);
  }
  bool containsTrack(Track track) => containsTrackKey(trackCollectionKey(track));
  bool containsTrackKey(String key) => _trackKeys.contains(key);
  Set<String> get trackKeys => Set.unmodifiable(_trackKeys);
  String? findAudioPathForTrack(String trackKey) { for (final entry in tracks) { if (entry.key == trackKey && entry.audioPath != null) return entry.audioPath; } return null; }
  String? findCoverPathForTrack(String trackKey) { for (final entry in tracks) { if (entry.key == trackKey && entry.coverPath != null) return entry.coverPath; } return null; }
}

class LibraryCollectionsState {
  final List<CollectionTrackEntry> wishlist;
  final List<CollectionTrackEntry> loved;
  final List<UserPlaylistCollection> playlists;
  final List<CollectionArtistEntry> favoriteArtists;
  final List<CollectionAlbumEntry> favoriteAlbums;
  final List<CollectionPlaylistEntry> favoritePlaylists;
  final bool isLoaded;
  final Set<String> _wishlistKeys;
  final Set<String> _lovedKeys;
  final Set<String> _canonicalLovedKeys;
  final Set<String> _favoriteArtistKeys;
  final Set<String> _favoriteAlbumKeys;
  final Set<String> _favoritePlaylistKeys;
  final Map<String, UserPlaylistCollection> _playlistsById;
  final Set<String> _allPlaylistTrackKeys;

  LibraryCollectionsState({this.wishlist = const [], this.loved = const [], this.playlists = const [], this.favoriteArtists = const [], this.favoriteAlbums = const [], this.favoritePlaylists = const [], this.isLoaded = false, Set<String>? wishlistKeys, Set<String>? lovedKeys, Set<String>? canonicalLovedKeys, Set<String>? favoriteArtistKeys, Set<String>? favoriteAlbumKeys, Set<String>? favoritePlaylistKeys, Map<String, UserPlaylistCollection>? playlistsById, Set<String>? allPlaylistTrackKeys})
    : _wishlistKeys = wishlistKeys ?? wishlist.map((entry) => entry.key).toSet(), _lovedKeys = lovedKeys ?? loved.map((entry) => entry.key).toSet(), _canonicalLovedKeys = canonicalLovedKeys ?? loved.map((entry) => canonicalLoveKey(entry.track)).toSet(), _favoriteArtistKeys = favoriteArtistKeys ?? favoriteArtists.map((entry) => entry.key).toSet(), _favoriteAlbumKeys = favoriteAlbumKeys ?? favoriteAlbums.map((entry) => entry.key).toSet(), _favoritePlaylistKeys = favoritePlaylistKeys ?? favoritePlaylists.map((entry) => entry.key).toSet(), _playlistsById = playlistsById ?? Map.fromEntries(playlists.map((pl) => MapEntry(pl.id, pl))), _allPlaylistTrackKeys = allPlaylistTrackKeys ?? _buildPlaylistTrackKeys(playlists);

  static Set<String> _buildPlaylistTrackKeys(List<UserPlaylistCollection> playlists) { final keys = <String>{}; for (final playlist in playlists) { keys.addAll(playlist._trackKeys); } return keys; }

  int get wishlistCount => wishlist.length;
  int get lovedCount => loved.length;
  int get playlistCount => playlists.length;
  int get favoriteArtistCount => favoriteArtists.length;
  int get favoriteAlbumCount => favoriteAlbums.length;
  int get favoritePlaylistCount => favoritePlaylists.length;

  bool isInWishlist(Track track) => _wishlistKeys.contains(trackCollectionKey(track));
  bool isLoved(Track track) => _canonicalLovedKeys.contains(canonicalLoveKey(track));
  String? findAudioPath(Track track) { final key = trackCollectionKey(track); for (final entry in loved) { if (entry.key == key && entry.audioPath != null) return entry.audioPath; } for (final entry in wishlist) { if (entry.key == key && entry.audioPath != null) return entry.audioPath; } return null; }
  String? findCoverPath(Track track) { final key = trackCollectionKey(track); for (final entry in loved) { if (entry.key == key && entry.coverPath != null) return entry.coverPath; } for (final entry in wishlist) { if (entry.key == key && entry.coverPath != null) return entry.coverPath; } return null; }
  bool containsWishlistKey(String trackKey) => _wishlistKeys.contains(trackKey);
  bool containsLovedKey(String trackKey) => _lovedKeys.contains(trackKey);

  bool isFavoriteArtist({required String artistId, required String? providerId, String? name}) {
    final key = artistCollectionKey(artistId: artistId, providerId: providerId);
    if (_favoriteArtistKeys.contains(key)) return true;
    if (name != null && name.isNotEmpty) { final n = normalizeForMatch(name); return favoriteArtists.any((e) => normalizeForMatch(e.name) == n); }
    return false;
  }

  bool containsFavoriteArtistKey(String artistKey) => _favoriteArtistKeys.contains(artistKey);

  bool isFavoriteAlbum({required String albumId, required String? providerId, String? name}) {
    if (name != null && name.isNotEmpty) { final n = normalizeForMatch(name); return favoriteAlbums.any((e) => normalizeForMatch(e.name) == n); }
    final key = albumCollectionKey(albumId: albumId, providerId: providerId);
    return _favoriteAlbumKeys.contains(key);
  }

  bool containsFavoriteAlbumKey(String albumKey) => _favoriteAlbumKeys.contains(albumKey);
  bool isFavoritePlaylist({required String playlistId, required String? providerId}) { final key = playlistCollectionKey(playlistId: playlistId, providerId: providerId); return _favoritePlaylistKeys.contains(key); }
  bool containsFavoritePlaylistKey(String playlistKey) => _favoritePlaylistKeys.contains(playlistKey);
  UserPlaylistCollection? playlistById(String id) => _playlistsById[id];
  bool isTrackInAnyPlaylist(String trackKey) => _allPlaylistTrackKeys.contains(trackKey);
  bool get hasPlaylistTracks => playlists.isNotEmpty;

  LibraryCollectionsState copyWith({List<CollectionTrackEntry>? wishlist, List<CollectionTrackEntry>? loved, List<UserPlaylistCollection>? playlists, List<CollectionArtistEntry>? favoriteArtists, List<CollectionAlbumEntry>? favoriteAlbums, List<CollectionPlaylistEntry>? favoritePlaylists, bool? isLoaded}) {
    final nw = wishlist ?? this.wishlist; final nl = loved ?? this.loved; final np = playlists ?? this.playlists; final nfa = favoriteArtists ?? this.favoriteArtists; final nfl = favoriteAlbums ?? this.favoriteAlbums; final nfp = favoritePlaylists ?? this.favoritePlaylists;
    return LibraryCollectionsState(wishlist: nw, loved: nl, playlists: np, favoriteArtists: nfa, favoriteAlbums: nfl, favoritePlaylists: nfp, isLoaded: isLoaded ?? this.isLoaded, wishlistKeys: identical(nw, this.wishlist) ? _wishlistKeys : null, lovedKeys: identical(nl, this.loved) ? _lovedKeys : null, favoriteArtistKeys: identical(nfa, this.favoriteArtists) ? _favoriteArtistKeys : null, favoriteAlbumKeys: identical(nfl, this.favoriteAlbums) ? _favoriteAlbumKeys : null, favoritePlaylistKeys: identical(nfp, this.favoritePlaylists) ? _favoritePlaylistKeys : null, playlistsById: identical(np, this.playlists) ? _playlistsById : null, allPlaylistTrackKeys: identical(np, this.playlists) ? _allPlaylistTrackKeys : null);
  }

  Map<String, dynamic> toJson() => {'wishlist': wishlist.map((e) => e.toJson()).toList(), 'loved': loved.map((e) => e.toJson()).toList(), 'playlists': playlists.map((p) => {'id': p.id, 'name': p.name, 'tracks': p.tracks.map((t) => t.toJson()).toList()}).toList(), 'favoriteArtists': favoriteArtists.map((e) => e.toJson()).toList()};

  factory LibraryCollectionsState.fromJson(Map<String, dynamic> json) => LibraryCollectionsState(isLoaded: true);
}
