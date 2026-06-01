import 'package:bitly/models/track.dart';
import 'package:bitly/providers/settings/settings_provider.dart';
import 'package:bitly/providers/extension/extension_provider.dart';
import 'package:bitly/providers/track/track_models.dart';
import 'package:bitly/providers/track/track_provider.dart';

extension TrackSearchHelpersExtension on TrackNotifier {
  String? resolveSearchProvider() {
    final settings = ref.read(settingsProvider);
    final extensionState = ref.read(extensionProvider);

    String? resolvedProvider;
    final explicitProvider = settings.searchProvider?.trim();
    if (explicitProvider != null && explicitProvider.isNotEmpty) {
      resolvedProvider = explicitProvider;
    } else {
      resolvedProvider =
          extensionState.extensions.where((ext) => ext.enabled && ext.hasCustomSearch && ext.searchBehavior?.primary == true).map((ext) => ext.id).firstOrNull ??
          extensionState.extensions.where((ext) => ext.enabled && ext.hasCustomSearch).map((ext) => ext.id).firstOrNull;
    }

    if (resolvedProvider != null && resolvedProvider.isNotEmpty && !extensionState.extensions.any((ext) => ext.enabled && ext.id == resolvedProvider) && settings.searchProvider?.trim() == resolvedProvider) {
      ref.read(settingsProvider.notifier).setSearchProvider(null);
      resolvedProvider =
          extensionState.extensions.where((ext) => ext.enabled && ext.hasCustomSearch && ext.searchBehavior?.primary == true).map((ext) => ext.id).firstOrNull ??
          extensionState.extensions.where((ext) => ext.enabled && ext.hasCustomSearch).map((ext) => ext.id).firstOrNull;
    }
    return resolvedProvider;
  }

  List<Track> parseTrackResults(List<dynamic> rawTracks) {
    final tracks = <Track>[];
    for (int i = 0; i < rawTracks.length; i++) {
      try { tracks.add(parseSearchTrack(rawTracks[i] as Map<String, dynamic>)); }
      catch (e) { log.e('Failed to parse track[$i]: $e', e); }
    }
    return tracks;
  }

  List<SearchArtist> parseSearchArtists(List<dynamic> rawArtists) {
    final artists = <SearchArtist>[];
    for (int i = 0; i < rawArtists.length; i++) {
      try { artists.add(parseSearchArtist(rawArtists[i] as Map<String, dynamic>)); }
      catch (e) { log.e('Failed to parse artist[$i]: $e', e); }
    }
    return artists;
  }

  List<SearchAlbum> parseSearchAlbums(List<dynamic> rawAlbums) {
    final albums = <SearchAlbum>[];
    for (int i = 0; i < rawAlbums.length; i++) {
      try { albums.add(parseSearchAlbum(rawAlbums[i] as Map<String, dynamic>)); }
      catch (e) { log.e('Failed to parse album[$i]: $e', e); }
    }
    return albums;
  }

  List<SearchPlaylist> parseSearchPlaylists(List<dynamic> rawPlaylists) {
    final playlists = <SearchPlaylist>[];
    for (int i = 0; i < rawPlaylists.length; i++) {
      try { playlists.add(parseSearchPlaylist(rawPlaylists[i] as Map<String, dynamic>)); }
      catch (e) { log.e('Failed to parse playlist[$i]: $e', e); }
    }
    return playlists;
  }
}
