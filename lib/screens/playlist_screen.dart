import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/services/history/history_lookup.dart';
import 'package:bitly/l10n/l10n.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/providers/download_queue_provider.dart';
import 'package:bitly/providers/extension_provider.dart';
import 'package:bitly/providers/library_collections_provider.dart';
import 'package:bitly/utils/file_access.dart';
import 'package:bitly/utils/image_cache_utils.dart';
import 'package:bitly/utils/string_utils.dart';
import 'package:bitly/providers/settings_provider.dart';
import 'package:bitly/providers/local_library_provider.dart';
import 'package:bitly/services/history/history_lookup.dart';
import 'package:bitly/providers/playback_provider.dart';
import 'package:bitly/services/history/history_lookup.dart';
import 'package:bitly/providers/audio_player_provider.dart';
import 'package:bitly/providers/lyrics_provider.dart';
import 'package:bitly/widgets/download_service_picker.dart';
import 'package:bitly/widgets/track_selection_sheet.dart';
import 'package:bitly/widgets/animation_utils.dart';
import 'package:bitly/widgets/cached_cover_image.dart';
import 'package:bitly/widgets/network_status.dart';
import 'package:bitly/widgets/track_card.dart';
import 'package:bitly/widgets/reactive_glass_background.dart';
import 'package:bitly/utils/logger.dart';

class PlaylistScreen extends ConsumerStatefulWidget {
  final String playlistName;
  final String? coverUrl;
  final List<Track> tracks;
  final String? playlistId;
  final String? recommendedService;
  final List<Track>? savedTracks;
  final String? extensionId;

  const PlaylistScreen({
    super.key,
    required this.playlistName,
    this.coverUrl,
    required this.tracks,
    this.playlistId,
    this.recommendedService,
    this.savedTracks,
    this.extensionId,
  });

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

final _log = AppLogger('PlaylistScreen');

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  bool _showTitleInAppBar = false;
  final ScrollController _scrollController = ScrollController();
  List<Track>? _fetchedTracks;
  bool _isLoading = false;
  String? _error;
  String? _resolvedPlaylistName;
  String? _resolvedCoverUrl;
  bool _isPlaylistLoved = false;

  List<Track> get _tracks => _fetchedTracks ?? widget.tracks;
  String get _playlistName => _resolvedPlaylistName ?? widget.playlistName;
  String? get _coverUrl => _resolvedCoverUrl ?? widget.coverUrl;

  void _loadPlaylistLikeStatus() {
    final id = widget.playlistId ?? 'name:${widget.playlistName.hashCode.abs()}';
    final trimmedId = id.trim();
    final key = trimmedId.contains(':')
        ? trimmedId
        : 'builtin:$trimmedId';
    final state = ref.read(libraryCollectionsProvider);
    if (state.isLoaded && mounted) {
      setState(() => _isPlaylistLoved = state.containsFavoritePlaylistKey(key));
    }
  }

  Future<void> _togglePlaylistLike() async {
    final id = widget.playlistId ?? 'name:${widget.playlistName.hashCode.abs()}';
    final notifier = ref.read(libraryCollectionsProvider.notifier);
    final trackEntries = _tracks.map((t) => CollectionTrackEntry(
      key: t.id,
      track: t,
      addedAt: DateTime.now(),
    )).toList();
    final added = await notifier.toggleFavoritePlaylist(
      playlistId: id,
      providerId: null,
      name: widget.playlistName,
      imageUrl: widget.coverUrl,
      trackCount: _tracks.length,
      tracks: trackEntries,
    );
    setState(() => _isPlaylistLoved = added);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(added ? 'Playlist guardada' : 'Playlist removida'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String? _legacyProviderIdFromResourceId(String value) {
    if (value.startsWith('deezer:')) return 'deezer';
    if (value.startsWith('qobuz:')) return 'qobuz-web';
    if (value.startsWith('tidal:')) return 'tidal-web';
    if (value.startsWith('spotify:')) return 'spotify-web';
    if (value.startsWith('apple-music:')) return 'apple-music';
    if (value.startsWith('soundcloud:')) return 'soundcloud';
    if (value.startsWith('ytmusic:')) return 'ytmusic-Bitly';
    if (value.startsWith('amazon:')) return 'amazon';
    if (value.startsWith('pandora:')) return 'pandora';
    return null;
  }

  String _stripPrefixedResourceId(String value) {
    final colonIndex = value.indexOf(':');
    if (colonIndex <= 0 || colonIndex == value.length - 1) {
      return value;
    }
    return value.substring(colonIndex + 1);
  }

  String? _metadataProviderId(String playlistId) {
    final providerId = _legacyProviderIdFromResourceId(playlistId);
    if (providerId == null) return null;
    final effective = resolveEffectiveMetadataProvider(
      providerId,
      ref.read(extensionProvider),
    );
    return effective.isEmpty ? null : effective;
  }

  String _metadataResourceId(String providerId, String playlistId) {
    return _stripPrefixedResourceId(playlistId);
  }

  String? _recommendedDownloadService() {
    final explicit = widget.recommendedService;
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }

    final playlistId = widget.playlistId;
    if (playlistId != null) {
      final providerId = _metadataProviderId(playlistId);
      if (providerId != null && providerId.isNotEmpty) {
        return resolveEffectiveDownloadService(
          providerId,
          ref.read(extensionProvider),
        );
      }
    }

    final source = _tracks.firstOrNull?.source;
    if (source != null && source.isNotEmpty) {
      return source;
    }

    final trackId = _tracks.firstOrNull?.id ?? '';
    final trackProviderId = _legacyProviderIdFromResourceId(trackId);
    if (trackProviderId != null) {
      return resolveEffectiveDownloadService(
        trackProviderId,
        ref.read(extensionProvider),
      );
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchTracksIfNeeded();
    // Cargar el estado del like después de que la biblioteca esté lista
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPlaylistLikeStatus();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchTracksIfNeeded() async {
    if (widget.tracks.isNotEmpty) return;

    final hadSavedTracks = widget.savedTracks != null && widget.savedTracks!.isNotEmpty;
    if (hadSavedTracks) {
      _fetchedTracks = widget.savedTracks;
    }

    if (widget.playlistId == null) {
      if (!hadSavedTracks) {
        final offlineTracks = await _collectOfflineTracks();
        if (offlineTracks.isNotEmpty && mounted) {
          setState(() {
            _fetchedTracks = offlineTracks;
            _isLoading = false;
          });
        }
      }
      return;
    }

    setState(() {
      _isLoading = !hadSavedTracks;
      _error = null;
    });

    try {
      String playlistId = widget.playlistId!;
      Map<String, dynamic>? result;
      String? sourceProvider;
      List<Track>? onlineTracks;

      // For builtin IDs (from library), skip direct metadata fetch and go straight to search
      if (!playlistId.startsWith('builtin:')) {
        sourceProvider = widget.extensionId ?? _metadataProviderId(playlistId);
        _log.d('_fetchTracksIfNeeded: sourceProvider=$sourceProvider playlistId=$playlistId');
        if (sourceProvider != null) {
          final rid = _metadataResourceId(sourceProvider, playlistId);
          _log.d('_fetchTracksIfNeeded: calling getProviderMetadata($sourceProvider, playlist, $rid)');
          try {
            result = await PlatformBridge.getProviderMetadata(
              sourceProvider,
              'playlist',
              rid,
            );
          } catch (e) {
            _log.d('_fetchTracksIfNeeded: getProviderMetadata threw: $e');
          }
        } else {
          sourceProvider = 'deezer';
          _log.d('_fetchTracksIfNeeded: fallback to deezer with playlistId=$playlistId');
          try {
            result = await PlatformBridge.getProviderMetadata(
              'deezer',
              'playlist',
              playlistId,
            );
          } catch (e) {
            _log.d('_fetchTracksIfNeeded: deezer fallback threw: $e');
          }
        }
      } else {
        _log.d('_fetchTracksIfNeeded: builtin playlistId, skipping direct metadata');
      }

      if (result != null && result['track_list'] != null) {
        final trackList = result['track_list'] as List<dynamic>? ?? [];
        _log.d('_fetchTracksIfNeeded: direct metadata returned ${trackList.length} tracks');
        try {
          onlineTracks = trackList
              .map((t) => _parseTrack(t as Map<String, dynamic>, source: sourceProvider ?? 'deezer'))
              .toList();
          _log.d('_fetchTracksIfNeeded: parsed ${onlineTracks.length} tracks successfully');
        } catch (e) {
          _log.d('_fetchTracksIfNeeded: _parseTrack threw: $e');
        }
      } else {
        _log.d('_fetchTracksIfNeeded: direct metadata returned null or no track_list');
      }

      // Search by name across providers as fallback
      if (onlineTracks == null || onlineTracks.isEmpty) {
        _log.d('_fetchTracksIfNeeded: trying search by name');
        if (!playlistId.startsWith('builtin:')) {
          try {
            onlineTracks = await _searchPlaylistTracksByName();
            _log.d('_fetchTracksIfNeeded: search by name returned ${onlineTracks?.length} tracks');
          } catch (e) {
            _log.d('_fetchTracksIfNeeded: _searchPlaylistTracksByName threw: $e');
          }
        } else {
          _log.d('_fetchTracksIfNeeded: builtin playlistId, skipping search by name');
        }
      }

      // Collect offline tracks (no setState)
      final offlineTracks = await _collectOfflineTracks();

      if (onlineTracks != null && onlineTracks.isNotEmpty) {
        final merged = _mergeTracks(onlineTracks, offlineTracks);
        if (mounted) {
          final playlistInfo = result?['playlist_info'] as Map<String, dynamic>?;
          final owner = playlistInfo?['owner'] as Map<String, dynamic>?;
          setState(() {
            _fetchedTracks = merged;
            _resolvedPlaylistName = (playlistInfo?['name'] ?? owner?['name'])?.toString();
            _resolvedCoverUrl = (playlistInfo?['images'] ?? owner?['images'])?.toString();
            _isLoading = false;
          });
        }
        return;
      }

      // Only offline tracks available
      if (offlineTracks.isNotEmpty || hadSavedTracks) {
        if (mounted) {
          setState(() {
            if (offlineTracks.isNotEmpty) _fetchedTracks = offlineTracks;
            _isLoading = false;
            _error = null;
          });
        }
        return;
      }

      // No tracks at all
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'No tracks found for this playlist';
        });
      }
    } catch (e) {
      _log.d('_fetchTracksIfNeeded: outer catch: $e');
      if (!mounted) return;
      await _loadOfflineTracks();
    }
  }

  Future<List<Track>> _collectOfflineTracks() async {
    final collectionsState = ref.read(libraryCollectionsProvider);
    final id = widget.playlistId ?? 'name:${widget.playlistName.hashCode.abs()}';
    final trimmedId = id.trim();
    final key = trimmedId.contains(':') ? trimmedId : 'builtin:$trimmedId';
    final isPlaylistLiked = collectionsState.containsFavoritePlaylistKey(key);

    final localTracks = <Track>[];
    final seenKeys = <String>{};

    void addTrackIfUnique(Track t) {
      final trackKey = t.isrc != null && t.isrc!.isNotEmpty
          ? 'isrc:${t.isrc}'
          : 'id:${t.id}';
      if (!seenKeys.contains(trackKey)) {
        seenKeys.add(trackKey);
        localTracks.add(t);
      }
    }

    // Tier 1: Si la playlist está en favoritos, usar sus tracks guardados
    if (isPlaylistLiked) {
      final favPlaylist = collectionsState.favoritePlaylists
          .where((p) {
            final pKey = p.key;
            return pKey == key || p.playlistId == trimmedId;
          })
          .firstOrNull;
      if (favPlaylist != null && favPlaylist.tracks != null && favPlaylist.tracks!.isNotEmpty) {
        for (final entry in favPlaylist.tracks!) {
          final track = entry.track;
          final enrichedTrack = entry.coverPath != null || entry.audioPath != null
              ? Track(
                  id: track.id,
                  name: track.name,
                  artistName: track.artistName,
                  albumName: track.albumName,
                  albumArtist: track.albumArtist,
                  artistId: track.artistId,
                  albumId: track.albumId,
                  coverUrl: entry.coverPath ?? track.coverUrl ?? widget.coverUrl,
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
                )
              : track;
          addTrackIfUnique(enrichedTrack);
        }
      }
    }

    // Tier 2: Si tenemos tracks del widget, verificar cuales existen localmente
    if (localTracks.isEmpty) {
      final sourceTracks = widget.savedTracks ?? widget.tracks;
      if (sourceTracks.isNotEmpty) {
        final historyNotifier = ref.read(downloadHistoryProvider.notifier);
        for (final track in sourceTracks) {
          final audioPath = collectionsState.findAudioPath(track);
          if (audioPath != null) {
            addTrackIfUnique(Track(
              id: track.id,
              name: track.name,
              artistName: track.artistName,
              albumName: track.albumName,
              albumArtist: track.albumArtist,
              artistId: track.artistId,
              albumId: track.albumId,
              coverUrl: track.coverUrl,
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
            ));
          } else {
            final isrc = track.isrc?.trim();
            DownloadHistoryItem? historyItem;
            if (isrc != null && isrc.isNotEmpty) {
              historyItem = await historyNotifier.getByIsrcAsync(isrc);
            }
            historyItem ??= await historyNotifier.findByTrackAndArtistAsync(
                track.name,
                track.artistName,
              );
            if (historyItem != null) {
              addTrackIfUnique(Track(
                id: track.id,
                name: track.name,
                artistName: track.artistName,
                albumName: track.albumName,
                albumArtist: track.albumArtist,
                artistId: track.artistId,
                albumId: track.albumId,
                coverUrl: track.coverUrl,
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
              ));
            }
          }
        }
      }
    }

    // Tier 3: Buscar descargas por nombre de playlist
    if (localTracks.isEmpty) {
      final playListName = widget.playlistName.toLowerCase().trim();
      final historyItems = ref.read(downloadHistoryProvider).items;
      for (final item in historyItems) {
        if (item.albumName.toLowerCase().trim() == playListName ||
            item.albumName.toLowerCase().trim().contains(playListName) ||
            playListName.contains(item.albumName.toLowerCase().trim())) {
          addTrackIfUnique(Track(
            id: item.spotifyId ?? 'hist_${item.id}',
            name: item.trackName,
            artistName: item.artistName,
            albumName: item.albumName,
            albumArtist: item.albumArtist,
            coverUrl: item.coverUrl,
            isrc: item.isrc,
            duration: item.duration ?? 0,
            trackNumber: item.trackNumber,
            discNumber: item.discNumber,
            totalDiscs: item.totalDiscs,
            totalTracks: item.totalTracks,
            releaseDate: item.releaseDate,
          ));
        }
      }
    }

    // Tier 4: Usar tracks likeados que coincidan con el nombre de la playlist
    if (localTracks.isEmpty) {
      final playListName = widget.playlistName.toLowerCase().trim();
      final loved = collectionsState.loved;
      for (final entry in loved) {
        final track = entry.track;
        final albumMatch = track.albumName.toLowerCase().trim() == playListName ||
            track.albumName.toLowerCase().trim().contains(playListName) ||
            playListName.contains(track.albumName.toLowerCase().trim());
        final trackMatch = track.name.toLowerCase().trim() == playListName ||
            track.name.toLowerCase().trim().contains(playListName);
        if (albumMatch || trackMatch) {
          addTrackIfUnique(track);
        }
      }
    }

    return localTracks;
  }

  Future<void> _loadOfflineTracks() async {
    final localTracks = await _collectOfflineTracks();
    if (mounted) {
      setState(() {
        _fetchedTracks = localTracks;
        _isLoading = false;
        if (localTracks.isEmpty) {
          _error = 'Playlist not available offline';
        }
      });
    }
  }

  Track _parseTrack(Map<String, dynamic> data, {String? source}) {
    int durationMs = 0;
    final durationValue = data['duration_ms'];
    if (durationValue is int) {
      durationMs = durationValue;
    } else if (durationValue is double) {
      durationMs = durationValue.toInt();
    }

    return Track(
      id: (data['spotify_id'] ?? data['id'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      artistName: (data['artists'] ?? data['artist'] ?? '').toString(),
      albumName: (data['album_name'] ?? data['album'] ?? '').toString(),
      albumArtist: data['album_artist']?.toString(),
      artistId: (data['artist_id'] ?? data['artistId'])?.toString(),
      albumId: data['album_id']?.toString(),
      coverUrl: normalizeCoverReference(
        (data['cover_url'] ?? data['images'])?.toString(),
      ),
      isrc: data['isrc']?.toString(),
      duration: (durationMs / 1000).round(),
      trackNumber: data['track_number'] as int?,
      discNumber: data['disc_number'] as int?,
      totalDiscs: data['total_discs'] as int?,
      releaseDate: data['release_date']?.toString(),
      totalTracks: data['total_tracks'] as int?,
      composer: data['composer']?.toString(),
      audioQuality: data['audio_quality']?.toString(),
      audioModes: data['audio_modes']?.toString(),
      source: source ?? widget.recommendedService ?? _metadataProviderId(widget.playlistId ?? ''),
    );
  }

  Future<List<Track>?> _searchPlaylistTracksByName() async {
    if (widget.playlistName.isEmpty) return null;
    final query = widget.playlistName.trim();
    final extState = ref.read(extensionProvider);
    final providers = extState.metadataProviderPriority.isNotEmpty
        ? extState.metadataProviderPriority
        : ['deezer', 'spotify-web', 'tidal-web', 'qobuz-web', 'apple-music'];

    for (final providerId in providers) {
      final ext = extState.extensions
          .where((e) => e.id == providerId && e.enabled && e.hasMetadataProvider)
          .firstOrNull;
      if (ext == null) continue;

      List<Map<String, dynamic>> results;
      try {
        results = await PlatformBridge.customSearchWithExtension(
          providerId,
          query,
        );
      } catch (_) {
        continue;
      }
      if (results.isEmpty) continue;

      try {
        // Find a track whose playlist name matches (if provider returns playlist info)
        final matchingResult = results.firstWhere(
          (r) {
            final name = (r['playlist_name'] ?? r['name'] ?? '')
                .toString()
                .toLowerCase()
                .trim();
            return name == query.toLowerCase() ||
                name.contains(query.toLowerCase());
          },
          orElse: () => results.first,
        );

        final playlistId = matchingResult['playlist_id']?.toString() ??
            matchingResult['id']?.toString();
        if (playlistId == null || playlistId.isEmpty) {
          // Fallback: return search results as playlist tracks
          final tracks = results
              .map((t) => _parseTrack(t, source: providerId))
              .toList();
          return tracks;
        }

        final metadata = await PlatformBridge.getProviderMetadata(
          providerId,
          'playlist',
          playlistId,
        );
        if (metadata['track_list'] == null) continue;

        final trackList = metadata['track_list'] as List<dynamic>? ?? [];
        final tracks = trackList
            .map((t) => _parseTrack(t as Map<String, dynamic>, source: providerId))
            .toList();
        return tracks;
      } catch (_) {
        continue;
      }
    }
    return null;
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

  @override
  Widget build(BuildContext context) {
    ref.listen(libraryCollectionsProvider, (prev, next) {
      if (next.isLoaded && mounted) _loadPlaylistLikeStatus();
    });
    final colorScheme = Theme.of(context).colorScheme;
    final collectionsState = ref.watch(libraryCollectionsProvider);
    final favCount = collectionsState.favoritePlaylistCount;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          ReactiveGlassBackground(
            coverUrl: _coverUrl,
            child: const SizedBox.expand(),
          ),
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildAppBar(context, colorScheme),
              _buildInfoCard(context, colorScheme),
              _buildTrackList(context, colorScheme),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, ColorScheme colorScheme) {
    final expandedHeight = _calculateExpandedHeight(context);

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: true,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      title: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _showTitleInAppBar ? 1.0 : 0.0,
        child: Text(
          _playlistName,
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
                if (_coverUrl != null)
                  CachedCoverImage(
                    imageUrl: _highResCoverUrl(_coverUrl) ?? _coverUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: cacheWidth,
                    placeholder: (_, _) =>
                        Container(color: colorScheme.surface),
                    errorWidget: (_, _, _) =>
                        Container(color: colorScheme.surface),
                  )
                else
                  Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.playlist_play,
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
                        const SizedBox(height: 8),
                        Text(
                          _playlistName,
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
                        if (_tracks.isNotEmpty) ...[
                          const SizedBox(height: 12),
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
                                  Icons.playlist_play,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  context.l10n.tracksCount(_tracks.length),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildPlaylistHeartButton(),
                              const SizedBox(width: 12),
                              _buildDownloadAllCenterButton(context),
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

  Widget _buildTrackList(BuildContext context, ColorScheme colorScheme) {
    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: TrackListSkeleton(itemCount: 8),
        ),
      );
    }

    if (_error != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            color: colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: colorScheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_tracks.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              context.l10n.errorNoTracksFound,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      );
    }

    final historyLookups = _tracks
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
        final track = _tracks[index];
        final isInHistory = existingHistoryKeys.contains(
          historyLookups[index].lookupKey,
        );
        return KeyedSubtree(
          key: ValueKey(track.id),
          child: StaggeredListItem(
            index: index,
            child: _PlaylistTrackItem(
              track: track,
              isInHistory: isInHistory,
              onDownload: () => _downloadTrack(context, track),
            ),
          ),
        );
      }, childCount: _tracks.length),
    );
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
        recommendedService: _recommendedDownloadService(),
        onSelect: (quality, service) {
          ref
              .read(downloadQueueProvider.notifier)
              .addToQueue(
                track,
                service,
                qualityOverride: quality,
                playlistName: _playlistName,
              );
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
      ref
          .read(downloadQueueProvider.notifier)
          .addToQueue(track, service, playlistName: _playlistName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.snackbarAddedToQueue(track.name))),
      );
    }
  }

  Widget _buildCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
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
        onPressed: onPressed,
        icon: Icon(icon, size: 22, color: Colors.white),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildPlaylistHeartButton() {
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
        onPressed: _togglePlaylistLike,
        icon: Icon(
          _isPlaylistLoved ? Icons.favorite : Icons.favorite_border,
          size: 22,
          color: _isPlaylistLoved ? Colors.redAccent : Colors.white,
        ),
        tooltip: _isPlaylistLoved ? 'Quitar de guardados' : 'Guardar playlist',
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildDownloadAllCenterButton(BuildContext context) {
    return FilledButton.icon(
      onPressed: _tracks.isEmpty ? null : () => _confirmDownloadAll(context),
      icon: const Icon(Icons.download_rounded, size: 18),
      label: Text(context.l10n.downloadAllCount(_tracks.length)),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  Widget _buildAddToPlaylistButton(BuildContext context) {
    return _buildCircleButton(
      icon: Icons.playlist_add,
      tooltip: context.l10n.tooltipAddToPlaylist,
      onPressed: _tracks.isEmpty
          ? null
          : () => showTrackSelectionForPlaylist(
              context, ref,
              title: context.l10n.tooltipAddToPlaylist,
              subtitle: widget.playlistName,
              tracks: _tracks,
            ),
    );
  }

  void _confirmDownloadAll(BuildContext context) {
    if (_tracks.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surfaceContainerHigh,
          title: Text(context.l10n.dialogDownloadAllTitle),
          content: Text(context.l10n.dialogDownloadAllMessage(_tracks.length)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.dialogCancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _downloadAll(context);
              },
              child: Text(context.l10n.dialogDownload),
            ),
          ],
        );
      },
    );
  }

  void _downloadAll(BuildContext context) {
    _downloadTracks(context, _tracks);
  }

  Future<void> _downloadTracks(BuildContext context, List<Track> tracks) async {
    final settings = ref.read(settingsProvider);
    if (!settings.isPremium && settings.premiumUntil == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Suscríbete a premium para descargar playlists compartidas'),
        ),
      );
      return;
    }
    if (tracks.isEmpty) return;

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
        artistName: _playlistName,
        recommendedService: _recommendedDownloadService(),
        onSelect: (quality, service) {
          ref
              .read(downloadQueueProvider.notifier)
              .addMultipleToQueue(
                tracksToQueue,
                service,
                qualityOverride: quality,
                playlistName: _playlistName,
              );
          _showQueuedSnackbar(context, tracksToQueue.length, skippedCount);
        },
      );
    } else {
      ref
          .read(downloadQueueProvider.notifier)
          .addMultipleToQueue(
            tracksToQueue,
            settings.defaultService,
            playlistName: _playlistName,
          );
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

  List<Track> _mergeTracks(List<Track> primary, List<Track> secondary) {
    final seenKeys = <String>{};
    final result = <Track>[];
    for (final t in primary) {
      final key = t.isrc ?? t.id;
      if (key.isNotEmpty && !seenKeys.contains(key)) {
        seenKeys.add(key);
        result.add(t);
      }
    }
    for (final t in secondary) {
      final key = t.isrc ?? t.id;
      if (key.isNotEmpty && !seenKeys.contains(key)) {
        seenKeys.add(key);
        result.add(t);
      }
    }
    return result;
  }
}

class _PlaylistTrackItem extends ConsumerWidget {
  final Track track;
  final bool isInHistory;
  final String? audioPath;
  final VoidCallback onDownload;

  const _PlaylistTrackItem({
    required this.track,
    required this.isInHistory,
    this.audioPath,
    required this.onDownload,
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

    double progress = 0;
    if (isQueued) progress = queueItem.progress;
    if (hasLocalFile) progress = 1;

    return TrackCard(
      track: track,
      showQualityBadge: true,
      showStatusDot: true,
      showHeartButton: true,
      showInfoButton: true,
      downloadProgress: progress,
      onDownload: hasLocalFile ? null : onDownload,
      onTap: () => _handleTap(context, ref, isQueued: isQueued, hasLocalFile: hasLocalFile),
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
        audioPath: audioPath ?? this.audioPath,
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
          SnackBar(content: Text('Could not play track. Download songs to play offline.')),
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
          await ref.read(playbackProvider.notifier).playLocalPath(
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
        await ref.read(playbackProvider.notifier).playLocalPath(
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


