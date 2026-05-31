import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bitly/services/biblioteca/portadas/cover_cache_manager.dart';
import 'package:bitly/l10n/l10n.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/providers/download_queue_provider.dart';
import 'package:bitly/providers/extension_provider.dart';
import 'package:bitly/providers/settings_provider.dart';
import 'package:bitly/providers/local_library_provider.dart';
import 'package:bitly/services/historial/history_lookup.dart';
import 'package:bitly/providers/playback_provider.dart';
import 'package:bitly/services/historial/history_lookup.dart';
import 'package:bitly/providers/audio_player_provider.dart';
import 'package:bitly/providers/lyrics_provider.dart';
import 'package:bitly/providers/recent_access_provider.dart';
import 'package:bitly/services/núcleo/platform_bridge.dart';
import 'package:bitly/services/historial/history_lookup.dart';
import 'package:bitly/utils/clickable_metadata.dart';
import 'package:bitly/providers/library_collections_provider.dart';
import 'package:bitly/utils/file_access.dart';
import 'package:bitly/utils/image_cache_utils.dart';
import 'package:bitly/utils/string_utils.dart';
import 'package:bitly/utils/logger.dart';
import 'package:bitly/widgets/network_status.dart';
import 'package:bitly/widgets/download_service_picker.dart';
import 'package:bitly/widgets/animation_utils.dart';
import 'package:bitly/widgets/track_card.dart';
import 'package:bitly/widgets/track_selection_sheet.dart';
import 'package:bitly/widgets/reactive_glass_background.dart';

class _AlbumCache {
  static final Map<String, _CacheEntry> _cache = {};
  static const Duration _ttl = Duration(minutes: 10);
  static const int _maxEntries = 50;

  static List<Track>? get(String albumId) {
    final entry = _cache[albumId];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(albumId);
      return null;
    }
    return entry.tracks;
  }

  static void set(String albumId, List<Track> tracks) {
    if (_cache.length >= _maxEntries) {
      final oldest = _cache.entries.reduce(
        (a, b) => a.value.expiresAt.isBefore(b.value.expiresAt) ? a : b,
      );
      _cache.remove(oldest.key);
    }
    _cache[albumId] = _CacheEntry(tracks, DateTime.now().add(_ttl));
  }
}

class _CacheEntry {
  final List<Track> tracks;
  final DateTime expiresAt;
  _CacheEntry(this.tracks, this.expiresAt);
}

final _log = AppLogger('AlbumScreen');

class AlbumScreen extends ConsumerStatefulWidget {
  final String albumId;
  final String albumName;
  final String? coverUrl;
  final List<Track>? tracks;
  final String? extensionId;
  final String? artistId;
  final String? artistName;

  const AlbumScreen({
    super.key,
    required this.albumId,
    required this.albumName,
    this.coverUrl,
    this.tracks,
    this.extensionId,
    this.artistId,
    this.artistName,
  });

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  List<Track>? _tracks;
  bool _isLoading = false;
  String? _error;
  bool _showTitleInAppBar = false;
  String? _artistId;
  String? _albumType;
  int? _albumTotalTracks;
  String? _albumCoverUrl;
  final ScrollController _scrollController = ScrollController();

  String _legacyProviderIdFromResourceId(String value) {
    if (value.startsWith('deezer:')) return 'deezer';
    if (value.startsWith('qobuz:')) return 'qobuz';
    if (value.startsWith('tidal:')) return 'tidal';
    if (value.startsWith('spotify:')) return 'spotify';
    return 'spotify';
  }

  String _effectiveMetadataProviderIdFromAlbumId() {
    if (widget.extensionId != null && widget.extensionId!.isNotEmpty) {
      return widget.extensionId!;
    }
    return resolveEffectiveMetadataProvider(
      _legacyProviderIdFromResourceId(widget.albumId),
      ref.read(extensionProvider),
    );
  }

  String _stripPrefixedResourceId(String value) {
    final colonIndex = value.indexOf(':');
    if (colonIndex <= 0 || colonIndex == value.length - 1) {
      return value;
    }
    return value.substring(colonIndex + 1);
  }

  @override
  void initState() {
    super.initState();

    _albumCoverUrl = widget.coverUrl;
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final providerId = _effectiveMetadataProviderIdFromAlbumId();
      ref
          .read(recentAccessProvider.notifier)
          .recordAlbumAccess(
            id: widget.albumId,
            name: widget.albumName,
            artistName:
                widget.artistName ??
                widget.tracks?.firstOrNull?.albumArtist ??
                widget.tracks?.firstOrNull?.artistName,
            imageUrl: widget.coverUrl,
            providerId: providerId,
          );
    });

    if (widget.tracks != null && widget.tracks!.isNotEmpty) {
      _tracks = widget.tracks;
    } else {
      _tracks = _AlbumCache.get(widget.albumId);
    }
    _artistId = widget.artistId;
    _albumType = _tracks?.firstOrNull?.albumType;
    _albumTotalTracks = _tracks?.firstOrNull?.totalTracks;

    if (_tracks == null || _tracks!.isEmpty) {
      _fetchTracks();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final expandedHeight = _calculateExpandedHeight(context);
    final shouldShow =
        _scrollController.offset > (expandedHeight - kToolbarHeight - 20);
    if (shouldShow != _showTitleInAppBar) {
      setState(() => _showTitleInAppBar = shouldShow);
    }
  }

  double _calculateExpandedHeight(BuildContext context) {
    final mediaSize = MediaQuery.of(context).size;
    return (mediaSize.height * 0.55).clamp(360.0, 520.0);
  }

  String? _highResCoverUrl(String? url) {
    if (url == null) return null;
    if (url.contains('ab67616d00001e02')) {
      return url.replaceAll('ab67616d00001e02', 'ab67616d0000b273');
    }
    final deezerRegex = RegExp(r'/(\d+)x(\d+)-(\d+)-(\d+)-(\d+)-(\d+)\.jpg$');
    if (url.contains('cdn-images.dzcdn.net') && deezerRegex.hasMatch(url)) {
      return url.replaceAllMapped(
        deezerRegex,
        (m) => '/1000x1000-${m[3]}-${m[4]}-${m[5]}-${m[6]}.jpg',
      );
    }
    return url;
  }

  String _formatReleaseDate(String date) {
    if (date.length >= 10) {
      final parts = date.substring(0, 10).split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    } else if (date.length >= 7) {
      final parts = date.split('-');
      if (parts.length >= 2) {
        return '${parts[1]}/${parts[0]}';
      }
    }
    return date;
  }

  Future<void> _fetchTracks() async {
    _log.d('_fetchTracks: albumId="${widget.albumId}" albumName="${widget.albumName}" artistName="${widget.artistName}"');
    setState(() => _isLoading = true);
    try {
      // For library albums (builtin IDs): try online first for full track listing,
      // then always merge with offline tracks (downloads + likes + playlists)
      if (widget.albumId.startsWith('builtin:')) {
        setState(() => _isLoading = true);
        List<Track>? onlineTracks;
        // Always try online search for library albums (connectivity check is unreliable on Windows)
        try {
          onlineTracks = await _searchAlbumTracksByName();
        } catch (e) {
          _log.d('_fetchTracks: _searchAlbumTracksByName threw: $e');
        }
        _log.d('_fetchTracks: onlineTracks=${onlineTracks?.length} tracks for album="${widget.albumName}"');
        if (onlineTracks != null && onlineTracks.isNotEmpty && _albumCoverUrl == null) {
          final firstCover = onlineTracks.firstWhere(
            (t) => t.coverUrl != null && t.coverUrl!.isNotEmpty,
            orElse: () => onlineTracks!.first,
          );
          if (firstCover.coverUrl != null && firstCover.coverUrl!.isNotEmpty) {
            _albumCoverUrl = firstCover.coverUrl;
          }
        }
        // Always load offline tracks (downloads, likes, playlists)
        await _loadOfflineTracks();
        final offlineTracks = _tracks ?? <Track>[];
        if (onlineTracks != null && onlineTracks.isNotEmpty) {
          // Merge: use online tracks as base, add offline tracks not already present
          final seenKeys = <String>{};
          for (final t in onlineTracks) {
            seenKeys.add(t.isrc ?? t.id);
          }
          for (final t in offlineTracks) {
            final key = t.isrc ?? t.id;
            if (key.isNotEmpty && !seenKeys.contains(key)) {
              onlineTracks.add(t);
              seenKeys.add(key);
            }
          }
          if (mounted) {
            _AlbumCache.set(widget.albumId, onlineTracks);
            setState(() {
              _tracks = onlineTracks;
              _isLoading = false;
              _error = null;
            });
          }
        } else if (offlineTracks.isNotEmpty) {
          // Only offline tracks found
          if (mounted) {
            setState(() {
              _isLoading = false;
              _error = null;
            });
          }
        } else {
          // No tracks at all
          if (mounted) {
            setState(() {
            _error = _error ?? 'No tracks found for this album';
            _isLoading = false;
          });
          }
        }
        return;
      }

      _log.d('_fetchTracks: online path for albumId="${widget.albumId}"');

      List<Track>? onlineTracks;
      String? artistId;
      String? albumType;
      int? albumTotalTracks;

      // Try direct provider metadata
      try {
        final directProviderId = _directMetadataProviderId();
        _log.d('_fetchTracks: directProviderId=$directProviderId');
        if (directProviderId != null) {
          final rid = _metadataResourceId(directProviderId);
          _log.d('_fetchTracks: calling getProviderMetadata($directProviderId, album, $rid)');
          final metadata = await PlatformBridge.getProviderMetadata(
            directProviderId,
            'album',
            rid,
          );
          if (metadata['track_list'] != null) {
            final trackList = metadata['track_list'] as List<dynamic>;
            _log.d('_fetchTracks: direct metadata returned ${trackList.length} tracks');
            final albumInfo = metadata['album_info'] as Map<String, dynamic>?;
            artistId = (albumInfo?['artist_id'] ?? albumInfo?['artistId'])
                ?.toString();
            albumType = normalizeOptionalString(
              albumInfo?['album_type']?.toString(),
            );
            albumTotalTracks = albumInfo?['total_tracks'] as int?;
            onlineTracks = trackList
                .map(
                  (t) => _parseTrack(
                    t as Map<String, dynamic>,
                    albumTypeFallback: albumType,
                    totalTracksFallback: albumTotalTracks,
                    source: directProviderId,
                  ),
                )
                .toList();
          } else {
            _log.d('_fetchTracks: direct metadata returned null or no track_list');
          }
        }
      } catch (e) {
        _log.d('_fetchTracks: direct provider metadata failed: $e');
      }

      // Try Spotify URL fallback
      if (onlineTracks == null) {
        try {
          final url = 'https://open.spotify.com/album/${widget.albumId}';
          _log.d('_fetchTracks: trying Spotify URL fallback: $url');
          final result = await PlatformBridge.handleURLWithExtension(url);
          if (result != null && result['tracks'] != null) {
            final trackList = result['tracks'] as List<dynamic>;
            _log.d('_fetchTracks: Spotify fallback returned ${trackList.length} tracks');
            final albumInfo = result['album'] as Map<String, dynamic>?;
            artistId = (albumInfo?['artist_id'] ?? albumInfo?['artistId'])
                ?.toString();
            albumType = normalizeOptionalString(
              albumInfo?['album_type']?.toString(),
            );
            albumTotalTracks = albumInfo?['total_tracks'] as int?;
            onlineTracks = trackList
                .map(
                  (t) => _parseTrack(
                    t as Map<String, dynamic>,
                    albumTypeFallback: albumType,
                    totalTracksFallback: albumTotalTracks,
                    source: 'spotify-web',
                  ),
                )
                .toList();
          } else {
            _log.d('_fetchTracks: Spotify fallback returned null or no tracks');
          }
        } catch (e) {
          _log.d('_fetchTracks: Spotify URL fallback failed: $e');
        }
      }

      // Search album by name+artist across metadata providers as last resort
      if (onlineTracks == null) {
        try {
          _log.d('_fetchTracks: trying search by name');
          final searchTracks = await _searchAlbumTracksByName();
          if (searchTracks != null && searchTracks.isNotEmpty) {
            _log.d('_fetchTracks: search by name returned ${searchTracks.length} tracks');
            onlineTracks = searchTracks;
            if (_albumCoverUrl == null && mounted) {
              final firstCover = searchTracks.firstWhere(
                (t) => t.coverUrl != null && t.coverUrl!.isNotEmpty,
                orElse: () => searchTracks.first,
              );
              if (firstCover.coverUrl != null && firstCover.coverUrl!.isNotEmpty) {
                setState(() => _albumCoverUrl = firstCover.coverUrl);
              }
            }
          } else {
            _log.d('_fetchTracks: search by name returned null/empty');
          }
        } catch (e) {
          _log.d('_fetchTracks: _searchAlbumTracksByName threw: $e');
        }
      }

      _log.d('_fetchTracks: after all online attempts, onlineTracks=${onlineTracks?.length}');

      // Always merge with offline tracks (downloads, likes, playlists)
      await _loadOfflineTracks();
      final offlineTracks = _tracks ?? <Track>[];

      if (onlineTracks != null && onlineTracks.isNotEmpty) {
        // Merge: online tracks as base, append offline tracks not already present
        final seenKeys = <String>{};
        for (final t in onlineTracks) {
          seenKeys.add(t.isrc ?? t.id);
        }
        for (final t in offlineTracks) {
          final key = t.isrc ?? t.id;
          if (key.isNotEmpty && !seenKeys.contains(key)) {
            onlineTracks.add(t);
            seenKeys.add(key);
          }
        }
        _AlbumCache.set(widget.albumId, onlineTracks);
        if (mounted) {
          setState(() {
            _tracks = onlineTracks;
            _artistId ??= artistId;
            _albumType ??= albumType;
            _albumTotalTracks ??= albumTotalTracks;
            _error = null;
            _isLoading = false;
          });
        }
      } else if (offlineTracks.isNotEmpty) {
        // Only offline tracks found
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'Could not fetch album from any provider. Please check your connection or try again later.';
          });
        }
      }
    } catch (e) {
      _log.d('_fetchTracks: error: $e');
      if (mounted) {
        await _loadOfflineTracks();
      }
    }
  }

  Future<void> _loadOfflineTracks() async {
    final collectionsState = ref.read(libraryCollectionsProvider);
    final localTracks = <Track>[];
    final seenKeys = <String>{};

    void addTrackIfUnique(Track t) {
      final key = t.isrc ?? t.id;
      if (key.isNotEmpty && !seenKeys.contains(key)) {
        seenKeys.add(key);
        localTracks.add(t);
      }
    }

    final albumName = widget.albumName;
    final rawArtist = _tracks?.firstOrNull?.albumArtist ??
        _tracks?.firstOrNull?.artistName ??
        widget.artistName;
    final artistName = rawArtist?.isNotEmpty == true ? rawArtist : null;

    // Tier 1: Si tenemos tracks del cache/widget, verificar cuales existen localmente
    if (_tracks != null && _tracks!.isNotEmpty) {
      final historyNotifier = ref.read(downloadHistoryProvider.notifier);
      final localLibraryNotifier = ref.read(localLibraryProvider.notifier);
      for (final track in _tracks!) {
        final hasHistory = await historyNotifier.findByTrackAndArtistAsync(
          track.name,
          track.artistName,
        ) != null;
        final hasLocal = await localLibraryNotifier.findExistingAsync(
          isrc: track.isrc,
          trackName: track.name,
          artistName: track.artistName,
        ) != null;
        if (hasHistory || hasLocal || collectionsState.isLoved(track)) {
          addTrackIfUnique(track);
        }
      }
    }

    // Tier 2: Buscar en historial de descargas por nombre de album
    if (localTracks.isEmpty && albumName.isNotEmpty) {
      final historyState = ref.read(downloadHistoryProvider);
      for (final item in historyState.items) {
        // Match by album name first, then try to match artist
        final albumMatches = item.albumName.toLowerCase() == albumName.toLowerCase();
        if (!albumMatches) continue;

        final artistMatches = artistName == null ||
            item.artistName.toLowerCase() == artistName.toLowerCase() ||
            (item.albumArtist != null &&
                item.albumArtist!.toLowerCase() == artistName.toLowerCase()) ||
            // Fallback: artist name contains each other
            (artistName.isNotEmpty && item.artistName.isNotEmpty &&
                (item.artistName.toLowerCase().contains(artistName.toLowerCase()) ||
                 artistName.toLowerCase().contains(item.artistName.toLowerCase())));

        if (!artistMatches) continue;
        addTrackIfUnique(Track(
          id: item.spotifyId ?? 'hist_${item.id}',
          name: item.trackName,
          artistName: item.artistName,
          albumName: item.albumName,
          albumArtist: item.albumArtist,
          coverUrl: _albumCoverUrl ?? item.coverUrl,
          isrc: item.isrc,
          duration: item.duration ?? 0,
          trackNumber: item.trackNumber,
          discNumber: item.discNumber,
          totalDiscs: item.totalDiscs,
          totalTracks: item.totalTracks,
          releaseDate: item.releaseDate,
          albumId: widget.albumId,
          artistId: _artistId ?? widget.artistId,
        ));
      }
    }

    // Tier 3: Buscar en tracks loved por nombre de album
    if (localTracks.isEmpty && albumName.isNotEmpty) {
      for (final entry in collectionsState.loved) {
        final track = entry.track;
        final albumMatchesLoved = track.albumName.toLowerCase() == albumName.toLowerCase();
        if (!albumMatchesLoved) continue;

        final artistMatchesLoved = artistName == null ||
            track.artistName.toLowerCase() == artistName.toLowerCase() ||
            (track.albumArtist != null &&
                track.albumArtist!.toLowerCase() ==
                    artistName.toLowerCase()) ||
            // Fallback: artist name contains each other
            (artistName.isNotEmpty && track.artistName.isNotEmpty &&
                (track.artistName.toLowerCase().contains(artistName.toLowerCase()) ||
                 artistName.toLowerCase().contains(track.artistName.toLowerCase())));

        if (!artistMatchesLoved) continue;
        final enrichedTrack = Track(
          id: track.id,
          name: track.name,
          artistName: track.artistName,
          albumName: track.albumName,
          albumArtist: track.albumArtist,
          artistId: track.artistId,
          albumId: track.albumId ?? widget.albumId,
          coverUrl: entry.coverPath ?? _albumCoverUrl ?? track.coverUrl,
          isrc: track.isrc,
          duration: track.duration,
          trackNumber: track.trackNumber,
          discNumber: track.discNumber,
          totalDiscs: track.totalDiscs,
          totalTracks: track.totalTracks,
          releaseDate: track.releaseDate,
          audioQuality: track.audioQuality,
          audioModes: track.audioModes,
          codec: track.codec,
          bitDepth: track.bitDepth,
          sampleRate: track.sampleRate,
        );
        addTrackIfUnique(enrichedTrack);
      }
    }

    // Tier 4: Buscar en playlists guardadas por nombre de album
    if (localTracks.isEmpty && albumName.isNotEmpty) {
      for (final playlist in collectionsState.playlists) {
        for (final entry in playlist.tracks) {
          final track = entry.track;
          final albumMatchesPlaylist = track.albumName.toLowerCase() == albumName.toLowerCase();
          if (!albumMatchesPlaylist) continue;

          final artistMatchesPlaylist = artistName == null ||
              track.artistName.toLowerCase() == artistName.toLowerCase() ||
              (track.albumArtist != null &&
                  track.albumArtist!.toLowerCase() ==
                      artistName.toLowerCase()) ||
              // Fallback: artist name contains each other
              (artistName.isNotEmpty && track.artistName.isNotEmpty &&
                  (track.artistName.toLowerCase().contains(artistName.toLowerCase()) ||
                   artistName.toLowerCase().contains(track.artistName.toLowerCase())));

          if (!artistMatchesPlaylist) continue;
          final enrichedTrack = Track(
            id: track.id,
            name: track.name,
            artistName: track.artistName,
            albumName: track.albumName,
            albumArtist: track.albumArtist,
            artistId: track.artistId,
            albumId: track.albumId ?? widget.albumId,
          coverUrl: entry.coverPath ?? _albumCoverUrl ?? track.coverUrl,
            isrc: track.isrc,
            duration: track.duration,
            trackNumber: track.trackNumber,
            discNumber: track.discNumber,
            totalDiscs: track.totalDiscs,
            totalTracks: track.totalTracks,
            releaseDate: track.releaseDate,
            audioQuality: track.audioQuality,
            audioModes: track.audioModes,
            codec: track.codec,
            bitDepth: track.bitDepth,
            sampleRate: track.sampleRate,
          );
          addTrackIfUnique(enrichedTrack);
        }
      }
    }

    // Try local cover.jpg in download directory if no cover set yet
    if (_albumCoverUrl == null && localTracks.isNotEmpty && albumName.isNotEmpty) {
      try {
        final settings = ref.read(settingsProvider);
        final baseDir = settings.downloadDirectory;
        if (baseDir.isNotEmpty) {
          final artist = rawArtist?.isNotEmpty == true ? rawArtist : null;
          String sanitize(String s) => s
              .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          final artistFolder = artist != null ? sanitize(artist) : '';
          final albumFolder = sanitize(albumName);
          final coverFile = File(p.join(baseDir, artistFolder, albumFolder, 'cover.jpg'));
          if (await coverFile.exists()) {
            _albumCoverUrl = coverFile.path;
          }
        }
      } catch (_) {}
    }

    _log.d('_loadOfflineTracks: found ${localTracks.length} tracks for album="$albumName" artist="$rawArtist"');
    if (mounted) {
      setState(() {
        _tracks = localTracks;
        _isLoading = false;
        if (localTracks.isEmpty) {
          _error = 'Album not available offline';
        }
      });
    }
  }

  String? _directMetadataProviderId() {
    final providerId = _effectiveMetadataProviderIdFromAlbumId();
    return providerId.isEmpty ? null : providerId;
  }

  String _metadataResourceId(String providerId) {
    return _stripPrefixedResourceId(widget.albumId);
  }

  Future<List<Track>?> _searchAlbumTracksByName() async {
    if (widget.albumName.isEmpty) return null;
    final query = '${widget.albumName} ${widget.artistName ?? ''}'.trim();
    _log.d('_searchAlbumTracksByName: query="$query"');
    final extState = ref.read(extensionProvider);
    final allProviders = extState.metadataProviderPriority.isNotEmpty
        ? extState.metadataProviderPriority
        : ['deezer', 'spotify-web', 'tidal-web', 'qobuz-web', 'apple-music'];
    final loadedIds = extState.extensions
        .where((e) => e.enabled && e.hasMetadataProvider)
        .map((e) => e.id)
        .toSet();
    final providers = allProviders.where((p) => loadedIds.contains(p)).toList();
    _log.d('_searchAlbumTracksByName: effectiveProviders=$providers');

    final allTracks = <Track>[];
    final seenKeys = <String>{};

    void addTrackIfUnique(Track t) {
      final key = t.isrc ?? t.name.toLowerCase().trim();
      if (key.isNotEmpty && !seenKeys.contains(key)) {
        seenKeys.add(key);
        allTracks.add(t);
      }
    }

    for (final providerId in providers) {
      if (allTracks.length >= 50) break;
      final ext = extState.extensions
          .where((e) => e.id == providerId && e.enabled && e.hasMetadataProvider)
          .firstOrNull;
      if (ext == null) continue;

      List<Map<String, dynamic>> searchResults;
      try {
        searchResults = await PlatformBridge.customSearchWithExtension(
          providerId,
          query,
        );
      } catch (_) {
        continue;
      }
      if (searchResults.isEmpty) continue;

      try {
        final albumTracks = <Map<String, dynamic>>[];
        final exactAlbumTracks = <Map<String, dynamic>>[];
        String? foundAlbumId;
        final targetAlbum = widget.albumName.toLowerCase().trim();
        final targetArtist = (widget.artistName ?? '').toLowerCase().trim();
        for (final r in searchResults) {
          final trackAlbumName = (r['album_name'] ?? '').toString().toLowerCase().trim();
          final albumObj = r['album'];
          final trackAlbumName2 = albumObj is Map ? (albumObj['name'] ?? '').toString().toLowerCase().trim() : '';
          final trackAlbumId = r['album_id']?.toString() ??
              (albumObj is Map ? albumObj['id']?.toString() : null);
          final trackArtist = (r['artists'] ?? '').toString().toLowerCase().trim();
          final albumArtist = albumObj is Map ? (albumObj['artist_name'] ?? albumObj['artists'] ?? '').toString().toLowerCase().trim() : '';
          final artist = (trackArtist.isNotEmpty ? trackArtist : albumArtist);

          // Exact album name match (with artist verification if targetArtist is known)
          final albumExact = trackAlbumName == targetAlbum || trackAlbumName2 == targetAlbum;
          if (albumExact && (targetArtist.isEmpty || artist.contains(targetArtist) || targetArtist.contains(artist))) {
            exactAlbumTracks.add(r);
            if (foundAlbumId == null || foundAlbumId.isEmpty) {
              foundAlbumId = trackAlbumId;
            }
            continue;
          }

          // Fuzzy match: album name contains each other AND artist matches exactly
          if (targetArtist.isNotEmpty && albumExact) continue; // already handled above
          final albumContains = !albumExact && (
            trackAlbumName.contains(targetAlbum) ||
            trackAlbumName2.contains(targetAlbum) ||
            targetAlbum.contains(trackAlbumName) ||
            targetAlbum.contains(trackAlbumName2)
          );
          if (!albumContains) continue;
          if (targetArtist.isNotEmpty && !artist.contains(targetArtist) && !targetArtist.contains(artist)) continue;

          albumTracks.add(r);
          if (foundAlbumId == null || foundAlbumId.isEmpty) {
            foundAlbumId = trackAlbumId;
          }
        }

        // Prefer exact matches, fall back to fuzzy
        final matchedTracks = exactAlbumTracks.isNotEmpty ? exactAlbumTracks : albumTracks;
        _log.d('_searchAlbumTracksByName: $providerId -> exact=${exactAlbumTracks.length} fuzzy=${albumTracks.length} kept=${matchedTracks.length}');

        List<Track>? providerTracks;
        if (foundAlbumId != null && foundAlbumId.isNotEmpty) {
          try {
            final metadata = await PlatformBridge.getProviderMetadata(
              providerId, 'album', foundAlbumId,
            );
            if (metadata['track_list'] != null) {
              final trackList = metadata['track_list'] as List<dynamic>;
              final albumInfo = metadata['album_info'] as Map<String, dynamic>?;
              final albumType = normalizeOptionalString(albumInfo?['album_type']?.toString());
              final totalTracks = albumInfo?['total_tracks'] as int?;
              providerTracks = trackList
                  .map((t) => _parseTrack(
                    t as Map<String, dynamic>,
                    albumTypeFallback: albumType,
                    totalTracksFallback: totalTracks,
                    source: providerId,
                  ))
                  .toList();
              _log.d('_searchAlbumTracksByName: $providerId -> ${providerTracks.length} tracks (full album)');
            }
          } catch (_) {}

          if (providerTracks == null) {
            try {
              final albumUrl = providerId == 'spotify-web'
                  ? 'https://open.spotify.com/album/$foundAlbumId'
                  : null;
              if (albumUrl != null) {
                final result = await PlatformBridge.handleURLWithExtension(albumUrl);
                if (result != null && result['tracks'] != null) {
                  final trackList = result['tracks'] as List<dynamic>;
                  final albumInfo = result['album'] as Map<String, dynamic>?;
                  final albumType = normalizeOptionalString(albumInfo?['album_type']?.toString());
                  final totalTracks = albumInfo?['total_tracks'] as int?;
                  providerTracks = trackList
                      .map((t) => _parseTrack(
                        t as Map<String, dynamic>,
                        albumTypeFallback: albumType,
                        totalTracksFallback: totalTracks,
                        source: 'spotify-web',
                      ))
                      .toList();
                  _log.d('_searchAlbumTracksByName: $providerId -> ${providerTracks.length} tracks (full album via URL)');
                }
              }
            } catch (_) {}
          }
        }

        if (providerTracks == null && matchedTracks.isNotEmpty) {
          providerTracks = matchedTracks
              .map((t) => _parseTrack(t, source: providerId))
              .toList();
          _log.d('_searchAlbumTracksByName: $providerId -> ${providerTracks.length} tracks (partial)');
        }

        if (providerTracks != null) {
          for (final t in providerTracks) {
            addTrackIfUnique(t);
          }
        }
      } catch (e) {
        _log.d('_searchAlbumTracksByName: $providerId threw: $e');
        continue;
      }
    }

    if (allTracks.isNotEmpty) {
      _AlbumCache.set(widget.albumId, allTracks);
      _log.d('_searchAlbumTracksByName: merged ${allTracks.length} tracks from $providers');
      return allTracks;
    }
    _log.d('_searchAlbumTracksByName: returning null (no provider matched)');
    return null;
  }

  Track _parseTrack(
    Map<String, dynamic> data, {
    String? albumTypeFallback,
    int? totalTracksFallback,
    String? source,
  }) {
    return Track(
      id: data['spotify_id'] as String? ?? data['id']?.toString() ?? '',
      name: data['name'] as String? ?? '',
      artistName: data['artists'] as String? ?? '',
      albumName: data['album_name'] as String? ?? '',
      albumArtist: data['album_artist'] as String?,
      artistId:
          (data['artist_id'] ?? data['artistId'])?.toString() ?? _artistId,
      albumId: data['album_id']?.toString() ?? widget.albumId,
      coverUrl: normalizeCoverReference(data['images']?.toString()),
      isrc: data['isrc'] as String?,
      duration: ((data['duration_ms'] as int? ?? 0) / 1000).round(),
      trackNumber: data['track_number'] as int?,
      discNumber: data['disc_number'] as int?,
      totalDiscs: data['total_discs'] as int?,
      releaseDate: data['release_date'] as String?,
      albumType:
          normalizeOptionalString(data['album_type']?.toString()) ??
          albumTypeFallback ??
          _albumType,
      totalTracks:
          data['total_tracks'] as int? ??
          totalTracksFallback ??
          _albumTotalTracks,
      composer: data['composer']?.toString(),
      audioQuality: data['audio_quality']?.toString(),
      audioModes: data['audio_modes']?.toString(),
      source: source ?? widget.extensionId ?? _effectiveMetadataProviderIdFromAlbumId(),
    );
  }

  String? _recommendedDownloadService() {
    return _directMetadataProviderId();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tracks = _tracks ?? [];
    final pageBackgroundColor = colorScheme.surface;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          ReactiveGlassBackground(
            coverUrl: _albumCoverUrl ?? widget.coverUrl,
            child: const SizedBox.expand(),
          ),
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildAppBar(context, colorScheme, pageBackgroundColor),
              _buildInfoCard(context, colorScheme),
              if (_isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: AlbumTrackListSkeleton(itemCount: 10),
                  ),
                ),
              if (_error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildErrorWidget(_error!, colorScheme),
                  ),
                ),
              if (!_isLoading && _error == null && tracks.isNotEmpty) ...[
                _buildTrackList(context, colorScheme, tracks),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    ColorScheme colorScheme,
    Color pageBackgroundColor,
  ) {
    final expandedHeight = _calculateExpandedHeight(context);
    final tracks = _tracks ?? [];
    final artistName =
        widget.artistName ??
        (tracks.isNotEmpty
            ? (tracks.first.albumArtist ?? tracks.first.artistName)
            : null);
    final releaseDate = tracks.isNotEmpty ? tracks.first.releaseDate : null;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: true,
      backgroundColor: pageBackgroundColor,
      surfaceTintColor: Colors.transparent,
      title: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _showTitleInAppBar ? 1.0 : 0.0,
        child: Text(
          widget.albumName,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final collapseRatio =
              (constraints.maxHeight - kToolbarHeight) /
              (expandedHeight - kToolbarHeight);
          final showContent = collapseRatio > 0.3;
          final cacheWidth = coverCacheWidthForViewport(context);

          return FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.coverUrl != null)
                  CachedNetworkImage(
                    imageUrl:
                        _highResCoverUrl(widget.coverUrl) ?? widget.coverUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: cacheWidth,
                    cacheManager: CoverCacheManager.instance,
                    placeholder: (_, _) =>
                        Container(color: colorScheme.surface),
                    errorWidget: (_, _, _) =>
                        Container(color: colorScheme.surface),
                  )
                else
                  Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.album,
                      size: 80,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: expandedHeight * 0.65,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 40,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: showContent ? 1.0 : 0.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.albumName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (artistName != null && artistName.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          ClickableArtistName(
                            artistName: artistName,
                            artistId: _artistId,
                            coverUrl: widget.coverUrl,
                            extensionId: widget.extensionId,
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (tracks.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.music_note,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      context.l10n.tracksCount(tracks.length),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (releaseDate != null && releaseDate.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatReleaseDate(releaseDate),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSourcePills(tracks, colorScheme),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildFavoriteAlbumButton(),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed: () => _downloadAll(context),
                                icon: Icon(Icons.download, size: 18),
                                label: Text(
                                  context.l10n.downloadAllCount(tracks.length),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black87,
                                  minimumSize: const Size(0, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              _buildAddToPlaylistButton(context),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            stretchModes: const [StretchMode.zoomBackground],
          );
        },
      ),
      actions: [
        const NetworkStatusIcon(),
      ],
      leading: IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, ColorScheme colorScheme) {
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }

  Widget _buildTrackList(
    BuildContext context,
    ColorScheme colorScheme,
    List<Track> tracks,
  ) {
    final historyLookups = tracks
        .map(historyLookupForTrack)
        .toList(growable: false);
    final existingHistoryKeys = ref
        .watch(
          downloadHistoryBatchExistsProvider(
            HistoryBatchLookupRequest(historyLookups),
          ),
        )
        .maybeWhen(data: (keys) => keys, orElse: () => const <String>{});
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final track = tracks[index];
        final isInHistory = existingHistoryKeys.contains(
          historyLookups[index].lookupKey,
        );
        final alts = _buildAlternateSources(track, tracks);
        return KeyedSubtree(
          key: ValueKey(track.id),
          child: StaggeredListItem(
            index: index,
            child: _AlbumTrackItem(
              track: track,
              albumCoverUrl: _albumCoverUrl,
              isInHistory: isInHistory,
              onDownload: () => _downloadTrack(context, track),
              alternateSources: alts,
            ),
          ),
        );
      }, childCount: tracks.length),
    );
  }

  List<Track>? _buildAlternateSources(Track track, List<Track> allAlbumTracks) {
    final alts = <Track>[];
    final seenSources = <String>{normalizeSource(track.source)};

    // Check loved tracks that match name/artist
    final collectionsState = ref.read(libraryCollectionsProvider);
    for (final entry in collectionsState.loved) {
      final lovedTrack = entry.track;
      if (track.id == lovedTrack.id && normalizeSource(track.source) == normalizeSource(lovedTrack.source)) continue;
      if (_tracksMatch(track, lovedTrack)) {
        final src = normalizeSource(lovedTrack.source);
        if (seenSources.add(src)) {
          alts.add(lovedTrack);
        }
      }
    }

    // Check other album tracks with matching name/artist but different source
    for (final altTrack in allAlbumTracks) {
      if (altTrack.id == track.id && normalizeSource(altTrack.source) == normalizeSource(track.source)) continue;
      if (_tracksMatch(track, altTrack)) {
        final src = normalizeSource(altTrack.source);
        if (seenSources.add(src)) {
          alts.add(altTrack);
        }
      }
    }

    // Check download history
    final historyState = ref.read(downloadHistoryProvider);
    for (final item in historyState.items) {
      if (_historyMatchesTrack(item, track)) {
        final src = normalizeSource(item.service);
        if (seenSources.add(src)) {
          alts.add(Track(
            id: item.spotifyId ?? 'hist_${item.id}',
            name: item.trackName,
            artistName: item.artistName,
            albumName: item.albumName,
            coverUrl: item.coverUrl,
            isrc: item.isrc,
            duration: item.duration ?? 0,
            source: item.service,
            audioQuality: item.quality,
            codec: item.format,
            bitDepth: item.bitDepth,
            sampleRate: item.sampleRate,
          ));
        }
      }
    }

    alts.sort((a, b) {
      final scoreA = _qualityScore(a);
      final scoreB = _qualityScore(b);
      return scoreB - scoreA;
    });

    return alts.isEmpty ? null : alts;
  }

  bool _tracksMatch(Track a, Track b) {
    if (a.isrc != null && b.isrc != null && a.isrc!.trim().isNotEmpty && b.isrc!.trim().isNotEmpty) {
      return a.isrc!.trim().toUpperCase() == b.isrc!.trim().toUpperCase();
    }
    return a.name.toLowerCase().trim() == b.name.toLowerCase().trim() &&
        a.artistName.toLowerCase().trim() == b.artistName.toLowerCase().trim();
  }

  bool _historyMatchesTrack(DownloadHistoryItem item, Track track) {
    if (item.isrc != null && track.isrc != null && item.isrc!.trim().isNotEmpty && track.isrc!.trim().isNotEmpty) {
      return item.isrc!.trim().toUpperCase() == track.isrc!.trim().toUpperCase();
    }
    if (item.spotifyId != null && item.spotifyId!.isNotEmpty && track.id.isNotEmpty) {
      return item.spotifyId == track.id;
    }
    return item.trackName.toLowerCase().trim() == track.name.toLowerCase().trim() &&
        item.artistName.toLowerCase().trim() == track.artistName.toLowerCase().trim();
  }

  int _qualityScore(Track t) {
    final q = (t.audioQuality ?? '').toLowerCase();
    if (q.contains('24') || q.contains('96') || q.contains('192')) return 5;
    if (q.contains('16') || q.contains('44.1') || q.contains('lossless')) return 4;
    if (q.contains('320') || q.contains('high')) return 3;
    if (q.contains('256') || q.contains('medium')) return 2;
    if (q.contains('128') || q.contains('low')) return 1;
    return 0;
  }

  void _downloadTrack(BuildContext context, Track track) {
    final settings = ref.read(settingsProvider);
    if (!settings.isPremium && settings.premiumUntil == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Suscríbete a premium para descargar'),
        ),
      );
      return;
    }
    if (settings.askQualityBeforeDownload) {
      DownloadServicePicker.show(
        context,
        trackName: track.name,
        artistName: track.artistName,
        coverUrl: track.coverUrl,
        durationSecs: track.duration,
        recommendedService: _recommendedDownloadService(),
        onSelect: (quality, service) {
          ref
              .read(downloadQueueProvider.notifier)
              .addToQueue(track, service, qualityOverride: quality);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.snackbarAddedToQueue(track.name)),
            ),
          );
        },
      );
    } else {
      final extensionState = ref.read(extensionProvider);
      final service = resolveEffectiveDownloadService(
        settings.defaultService,
        extensionState,
      );
      if (service.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.extensionsNoDownloadProvider)),
        );
        return;
      }
      ref.read(downloadQueueProvider.notifier).addToQueue(track, service);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.snackbarAddedToQueue(track.name))),
      );
    }
  }

  Future<void> _downloadAll(BuildContext context) async {
    final settings = ref.read(settingsProvider);
    if (!settings.isPremium && settings.premiumUntil == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Suscríbete a premium para descargar álbumes completos'),
        ),
      );
      return;
    }
    final tracks = _tracks;
    if (tracks == null || tracks.isEmpty) return;

    final historyLookups = tracks
        .map(historyLookupForTrack)
        .toList(growable: false);
    final existingHistoryKeys = await ref.read(
      downloadHistoryBatchExistsProvider(
        HistoryBatchLookupRequest(historyLookups),
      ).future,
    );
    if (!context.mounted) return;
    final localLibState =
        (settings.localLibraryEnabled && settings.localLibraryShowDuplicates)
        ? ref.read(localLibraryProvider)
        : null;
    final tracksToQueue = <Track>[];
    int skippedCount = 0;

    for (var i = 0; i < tracks.length; i++) {
      final track = tracks[i];
      final isInHistory = existingHistoryKeys.contains(
        historyLookups[i].lookupKey,
      );
      final isInLocal =
          localLibState?.existsInLibrary(
            isrc: track.isrc,
            trackName: track.name,
            artistName: track.artistName,
          ) ??
          false;

      if (isInHistory || isInLocal) {
        skippedCount++;
      } else {
        tracksToQueue.add(track);
      }
    }

    if (tracksToQueue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.discographySkippedDownloaded(0, skippedCount),
          ),
        ),
      );
      return;
    }

    if (settings.askQualityBeforeDownload) {
      DownloadServicePicker.show(
        context,
        trackName: '${tracksToQueue.length} tracks',
        artistName: widget.albumName,
        recommendedService: _recommendedDownloadService(),
        onSelect: (quality, service) {
          ref
              .read(downloadQueueProvider.notifier)
              .addMultipleToQueue(
                tracksToQueue,
                service,
                qualityOverride: quality,
              );
          _showQueuedSnackbar(context, tracksToQueue.length, skippedCount);
        },
      );
    } else {
      final extensionState = ref.read(extensionProvider);
      final service = resolveEffectiveDownloadService(
        settings.defaultService,
        extensionState,
      );
      if (service.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.extensionsNoDownloadProvider)),
        );
        return;
      }
      ref
          .read(downloadQueueProvider.notifier)
          .addMultipleToQueue(tracksToQueue, service);
      _showQueuedSnackbar(context, tracksToQueue.length, skippedCount);
    }
  }

  void _showQueuedSnackbar(BuildContext context, int added, int skipped) {
    final message = skipped > 0
        ? context.l10n.discographySkippedDownloaded(added, skipped)
        : context.l10n.snackbarAddedTracksToQueue(added);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildFavoriteAlbumButton() {
    final collectionsState = ref.watch(libraryCollectionsProvider);
    final isFav = collectionsState.isFavoriteAlbum(
      albumId: widget.albumId,
      providerId: null,
      name: widget.albumName,
    );

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: () => _toggleFavoriteAlbum(),
        icon: Icon(
          isFav ? Icons.favorite : Icons.favorite_border,
          size: 22,
          color: isFav ? Colors.redAccent : Colors.white,
        ),
        tooltip: isFav
            ? context.l10n.trackOptionRemoveFromLoved
            : context.l10n.tooltipLoveAll,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildAddToPlaylistButton(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: _tracks == null || _tracks!.isEmpty
            ? null
            : () => showTrackSelectionForPlaylist(
                context, ref,
                title: context.l10n.tooltipAddToPlaylist,
                subtitle: widget.albumName,
                tracks: _tracks!,
              ),
        icon: const Icon(Icons.add, size: 22, color: Colors.white),
        tooltip: context.l10n.tooltipAddToPlaylist,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Future<void> _toggleFavoriteAlbum() async {
    final notifier = ref.read(libraryCollectionsProvider.notifier);
    final added = await notifier.toggleFavoriteAlbum(
      albumId: widget.albumId,
      providerId: null,
      name: widget.albumName,
      artistName: widget.artistName,
      imageUrl: widget.coverUrl,
      totalTracks: _tracks?.length,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(added
              ? '${widget.albumName} added to favorites'
              : '${widget.albumName} removed from favorites'),
        ),
      );
    }
  }

  Widget _buildSourcePills(List<Track> tracks, ColorScheme colorScheme) {
    final collectionsState = ref.watch(libraryCollectionsProvider);
    final historyState = ref.watch(downloadHistoryProvider);
    final extState = ref.watch(extensionProvider);

    final lovedBySource = <String, int>{};
    final downloadedBySource = <String, int>{};

    for (final t in tracks) {
      if (collectionsState.isLoved(t)) {
        final src = normalizeSource(t.source);
        lovedBySource[src] = (lovedBySource[src] ?? 0) + 1;
      }
    }

    for (final t in tracks) {
      bool found = false;
      if (t.isrc != null && t.isrc!.trim().isNotEmpty) {
        found = historyState.getByIsrc(t.isrc!) != null;
      }
      if (!found) {
        found = historyState.findByTrackAndArtist(t.name, t.artistName) != null;
      }
      if (!found && t.id.isNotEmpty) {
        found = historyState.getBySpotifyId(t.id) != null;
      }
      if (found) {
        final src = normalizeSource(t.source);
        downloadedBySource[src] = (downloadedBySource[src] ?? 0) + 1;
      }
    }

    final lovedSources = lovedBySource.entries.toList();
    final downloadedSources = downloadedBySource.entries.toList();

    if (lovedSources.isEmpty && downloadedSources.isEmpty) {
      return const SizedBox.shrink();
    }

    final pills = <Widget>[];
    for (final entry in lovedSources) {
      final ext = extState.extensions.where((e) => e.id == entry.key).firstOrNull;
      final displayName = ext?.displayName ?? entry.key;
      pills.add(_sourcePill(
        icon: Icons.favorite,
        iconColor: Colors.redAccent,
        label: '$displayName (${entry.value})',
        colorScheme: colorScheme,
      ));
    }
    for (final entry in downloadedSources) {
      final ext = extState.extensions.where((e) => e.id == entry.key).firstOrNull;
      final displayName = ext?.displayName ?? entry.key;
      pills.add(_sourcePill(
        icon: Icons.download_done,
        iconColor: Colors.green,
        label: '$displayName (${entry.value})',
        colorScheme: colorScheme,
      ));
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: pills,
    );
  }

  Widget _sourcePill({
    required IconData icon,
    required Color iconColor,
    required String label,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error, ColorScheme colorScheme) {
    final isRateLimit =
        error.contains('429') ||
        error.toLowerCase().contains('rate limit') ||
        error.toLowerCase().contains('too many requests');

    if (isRateLimit) {
      return Card(
        elevation: 0,
        color: colorScheme.errorContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.timer_off, color: colorScheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.errorRateLimited,
                      style: TextStyle(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.errorRateLimitedMessage,
                      style: TextStyle(
                        color: colorScheme.onErrorContainer,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: colorScheme.errorContainer.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(error, style: TextStyle(color: colorScheme.error)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumTrackItem extends ConsumerWidget {
  final Track track;
  final String? albumCoverUrl;
  final bool isInHistory;
  final VoidCallback onDownload;
  final List<Track>? alternateSources;

  const _AlbumTrackItem({
    required this.track,
    required this.albumCoverUrl,
    required this.isInHistory,
    required this.onDownload,
    this.alternateSources,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueItem = ref.watch(
      downloadQueueLookupProvider.select(
        (lookup) => lookup.byTrackId[track.id],
      ),
    );

    final showLocalLibraryIndicator = ref.watch(
      settingsProvider.select(
        (s) => s.localLibraryEnabled && s.localLibraryShowDuplicates,
      ),
    );
    final isInLocalLibrary = showLocalLibraryIndicator
        ? ref.watch(
            localLibraryProvider.select(
              (state) => state.existsInLibrary(
                isrc: track.isrc,
                trackName: track.name,
                artistName: track.artistName,
              ),
            ),
          )
        : false;

    final isQueued = queueItem != null;
    final hasLocalFile = isInHistory || isInLocalLibrary;
    final effectiveCoverUrl = albumCoverUrl ?? track.coverUrl ?? queueItem?.track.coverUrl;

    double progress = 0;
    if (isQueued) progress = 0.5;
    if (hasLocalFile) progress = 1;

    return TrackCard(
      track: track,
      albumCoverUrl: effectiveCoverUrl,
      showQualityBadge: true,
      showExplicitBadge: false,
      showStatusDot: true,
      showHeartButton: true,
      showInfoButton: true,
      downloadProgress: progress,
      onDownload: hasLocalFile ? null : onDownload,
      onTap: () => _handleTap(context, ref, isQueued: isQueued, hasLocalFile: hasLocalFile),
    );
  }

  void _onAlternateSourceSelected(BuildContext context, WidgetRef ref, Track selected) {
    // Try to play local file first, then stream
    final collectionsState = ref.read(libraryCollectionsProvider);
    final audioPath = collectionsState.findAudioPath(selected);
    if (audioPath != null) {
      fileExists(audioPath).then((exists) {
        if (exists && context.mounted) {
          ref.read(playbackProvider.notifier).playLocalPath(
            path: audioPath,
            title: selected.name,
            artist: selected.artistName,
            album: selected.albumName,
            coverUrl: selected.coverUrl ?? '',
          );
          return;
        }
        _streamTrack(context, ref, selected);
      });
    } else {
      _streamTrack(context, ref, selected);
    }
  }

  void _streamTrack(BuildContext context, WidgetRef ref, Track t) {
    ref.read(audioPlayerProvider.notifier).play(
      trackId: t.id,
      trackName: t.name,
      artistName: t.artistName,
      albumName: t.albumName,
      coverUrl: t.coverUrl,
      provider: t.source ?? 'deezer',
      isrc: t.isrc,
    );
  }

  void _handleTap(
    BuildContext context,
    WidgetRef ref, {
    required bool isQueued,
    required bool hasLocalFile,
  }) async {
    if (isQueued) return;

    final collectionsState = ref.read(libraryCollectionsProvider);
    final audioPath = collectionsState.findAudioPath(track);

    final playedLocal = await _playLocalIfAvailable(context, ref, audioPath: audioPath);
    if (playedLocal) return;

    if (!context.mounted) return;

    try {
      // Reproducir INMEDIATAMENTE
      ref.read(audioPlayerProvider.notifier).play(
        trackId: track.id,
        trackName: track.name,
        artistName: track.artistName,
        albumName: track.albumName,
        coverUrl: track.coverUrl,
        provider: track.source ?? 'deezer',
        isrc: track.isrc,
        audioPath: audioPath,
      );

      // Pre-cargar video y letra EN PARALELO (sin bloquear el audio)
      Future(() {
        ref.read(audioPlayerProvider.notifier).prefetchVideo(track.name, track.artistName);
        ref.read(lyricsProvider.notifier).fetchForTrack(
          trackId: track.id,
          trackName: track.name,
          artistName: track.artistName,
          durationMs: 0,
        );
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not play track. Download songs to play offline.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<bool> _playLocalIfAvailable(
    BuildContext context,
    WidgetRef ref, {
    String? audioPath,
  }) async {
    final historyNotifier = ref.read(downloadHistoryProvider.notifier);

    if (audioPath != null && await fileExists(audioPath)) {
      await ref.read(playbackProvider.notifier).playLocalPath(
        path: audioPath,
        title: track.name,
        artist: track.artistName,
        album: track.albumName,
        coverUrl: track.coverUrl ?? '',
      );
      return true;
    }

    try {
      DownloadHistoryItem? historyItem = await historyNotifier
          .getBySpotifyIdAsync(track.id);
      final isrc = track.isrc?.trim();
      historyItem ??= (isrc != null && isrc.isNotEmpty)
          ? await historyNotifier.getByIsrcAsync(isrc)
          : null;
      historyItem ??= await historyNotifier.findByTrackAndArtistAsync(
        track.name,
        track.artistName,
      );

      if (historyItem != null) {
        final exists = await fileExists(historyItem.filePath);
        if (exists) {
          await ref
              .read(playbackProvider.notifier)
              .playLocalPath(
                path: historyItem.filePath,
                title: track.name,
                artist: track.artistName,
                album: track.albumName,
                coverUrl: track.coverUrl ?? '',
              );
          return true;
        }
        historyNotifier.removeFromHistory(historyItem.id);
      }

      final localItem = await ref
          .read(localLibraryProvider.notifier)
          .findExistingAsync(
            isrc: isrc,
            trackName: track.name,
            artistName: track.artistName,
          );

      if (localItem != null && await fileExists(localItem.filePath)) {
        await ref
            .read(playbackProvider.notifier)
            .playLocalPath(
              path: localItem.filePath,
              title: localItem.trackName,
              artist: localItem.artistName,
              album: localItem.albumName,
              coverUrl: localItem.coverPath ?? track.coverUrl ?? '',
            );
        return true;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.snackbarCannotOpenFile('$e'))),
        );
      }
      return true;
    }

    return false;
  }
}


