import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:bitly/l10n/l10n.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/providers/extension_provider.dart';
import 'package:bitly/providers/track_provider.dart';
import 'package:bitly/providers/settings_provider.dart';
import 'package:bitly/providers/download_queue_provider.dart';
import 'package:bitly/providers/library_collections_provider.dart';
import 'package:bitly/providers/recent_access_provider.dart';
import 'package:bitly/providers/local_library_provider.dart';
import 'package:bitly/services/historial/history_lookup.dart';
import 'package:bitly/providers/playback_provider.dart';
import 'package:bitly/services/historial/history_lookup.dart';
import 'package:bitly/providers/lyrics_provider.dart';
import 'package:bitly/services/núcleo/platform_bridge.dart';
import 'package:bitly/services/historial/history_lookup.dart';
import 'package:bitly/utils/artist_utils.dart';
import 'package:bitly/utils/file_access.dart';
import 'package:bitly/utils/string_utils.dart';
import 'package:bitly/services/historial/history_database.dart';
import 'package:bitly/screens/album_screen.dart';
import 'package:bitly/screens/home_tab.dart'
    show ExtensionAlbumScreen;
import 'package:bitly/widgets/download_service_picker.dart';
import 'package:bitly/providers/audio_player_provider.dart';
import 'package:bitly/widgets/animation_utils.dart';
import 'package:bitly/widgets/track_selection_sheet.dart';
import 'package:bitly/widgets/track_card.dart';
import 'package:bitly/widgets/album_card.dart';
import 'package:bitly/widgets/reactive_glass_background.dart';
import 'package:bitly/widgets/cached_cover_image.dart';
import 'package:bitly/widgets/network_status.dart';

class _ArtistCache {
  static final Map<String, _CacheEntry> _cache = {};
  static const Duration _ttl = Duration(minutes: 10);

  static _CacheEntry? get(String artistId) {
    final entry = _cache[artistId];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(artistId);
      return null;
    }
    return entry;
  }

  static void set(
    String artistId, {
    required List<ArtistAlbum> albums,
    List<ArtistAlbum>? releases,
    List<Track>? topTracks,
    String? headerImageUrl,
    int? monthlyListeners,
  }) {
    _cache[artistId] = _CacheEntry(
      albums: albums,
      releases: releases,
      topTracks: topTracks,
      headerImageUrl: headerImageUrl,
      monthlyListeners: monthlyListeners,
      expiresAt: DateTime.now().add(_ttl),
    );
  }
}

class _CacheEntry {
  final List<ArtistAlbum> albums;
  final List<ArtistAlbum>? releases;
  final List<Track>? topTracks;
  final String? headerImageUrl;
  final int? monthlyListeners;
  final DateTime expiresAt;

  _CacheEntry({
    required this.albums,
    this.releases,
    this.topTracks,
    this.headerImageUrl,
    this.monthlyListeners,
    required this.expiresAt,
  });
}

class _ArtistSearchResult {
  final List<ArtistAlbum> albums;
  final List<ArtistAlbum>? releases;
  final List<Track>? topTracks;
  final String? headerImage;
  final int? listeners;

  _ArtistSearchResult({
    required this.albums,
    this.releases,
    this.topTracks,
    this.headerImage,
    this.listeners,
  });
}

class ArtistScreen extends ConsumerStatefulWidget {
  final String artistId;
  final String artistName;
  final String? coverUrl;
  final String? headerImageUrl;
  final int? monthlyListeners;
  final List<ArtistAlbum>? albums;
  final List<Track>? topTracks;
  final String? extensionId;

  const ArtistScreen({
    super.key,
    required this.artistId,
    required this.artistName,
    this.coverUrl,
    this.headerImageUrl,
    this.monthlyListeners,
    this.albums,
    this.topTracks,
    this.extensionId,
  });

  @override
  ConsumerState<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends ConsumerState<ArtistScreen> {
  List<ArtistAlbum>? _albums;
  List<ArtistAlbum>? _releases;
  List<Track>? _topTracks;
  String? _headerImageUrl;
  int? _monthlyListeners;
  bool _isLoadingDiscography = false;
  String? _error;
  bool _showTitleInAppBar = false;
  final ScrollController _scrollController = ScrollController();
  final PageController _popularPageController = PageController();
  final Map<String, List<Track>> _localAlbumTracksMap = {};
  int _popularCurrentPage = 0;

  bool _isSelectionMode = false;
  final Set<String> _selectedAlbumIds = {};
  bool _isFetchingDiscography = false;
  List<ArtistAlbum>? _albumBucketSource;
  List<ArtistAlbum> _albumsOnlyBucket = const [];
  List<ArtistAlbum> _singlesBucket = const [];
  List<ArtistAlbum> _compilationsBucket = const [];

  double _responsiveScale({
    double min = 0.82,
    double max = 1.08,
    double baseShortestSide = 390,
  }) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final scale = shortestSide / baseShortestSide;
    if (scale < min) return min;
    if (scale > max) return max;
    return scale;
  }

  double _effectiveTextScale() {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    if (textScale < 1.0) return 1.0;
    if (textScale > 1.4) return 1.4;
    return textScale;
  }

  double _artistAlbumTileSize() {
    final scale = _responsiveScale(min: 0.82, max: 1.05);
    final textScale = _effectiveTextScale();
    return 119 * scale * (1 + (textScale - 1) * 0.12);
  }

  double _artistAlbumSectionHeight() {
    final tileSize = _artistAlbumTileSize();
    final textScale = _effectiveTextScale();
    return tileSize + 64 + ((textScale - 1) * 14);
  }

  String? _recommendedDownloadService() {
    return _directMetadataProviderId();
  }

  String _legacyProviderIdFromResourceId(String value) {
    if (value.startsWith('deezer:')) return 'deezer';
    if (value.startsWith('qobuz:')) return 'qobuz';
    if (value.startsWith('tidal:')) return 'tidal';
    if (value.startsWith('spotify:')) return 'spotify';
    return 'spotify';
  }

  String _effectiveMetadataProviderIdFromArtistId() {
    if (widget.extensionId != null && widget.extensionId!.isNotEmpty) {
      return widget.extensionId!;
    }
    return resolveEffectiveMetadataProvider(
      _legacyProviderIdFromResourceId(widget.artistId),
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

  String? _directMetadataProviderId() {
    final providerId = _effectiveMetadataProviderIdFromArtistId();
    return providerId.isEmpty ? null : providerId;
  }

  String _metadataResourceId(String providerId) {
    return _stripPrefixedResourceId(widget.artistId);
  }

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final providerId = _effectiveMetadataProviderIdFromArtistId();
      ref
          .read(recentAccessProvider.notifier)
          .recordArtistAccess(
            id: widget.artistId,
            name: widget.artistName,
            imageUrl: widget.coverUrl,
            providerId: providerId,
          );
    });

    if (widget.extensionId != null) {
      _albums = widget.albums;
      _topTracks = widget.topTracks;
      _headerImageUrl = widget.headerImageUrl;
      _monthlyListeners = widget.monthlyListeners;

      if ((_albums == null || _albums!.isEmpty) ||
          (_topTracks == null || _topTracks!.isEmpty)) {
        _fetchDiscography();
      }
      return;
    }

    final cached = _ArtistCache.get(widget.artistId);

    if (widget.albums != null) {
      _albums = widget.albums;
      _topTracks = widget.topTracks;
      _headerImageUrl = widget.headerImageUrl;
      _monthlyListeners = widget.monthlyListeners;

      if (_topTracks == null || _topTracks!.isEmpty) {
        _fetchDiscography();
      }
    } else if (cached != null) {
      _albums = cached.albums;
      _releases = cached.releases;
      _topTracks = cached.topTracks;
      _headerImageUrl = cached.headerImageUrl;
      _monthlyListeners = cached.monthlyListeners;

      if (_topTracks == null || _topTracks!.isEmpty) {
        _fetchDiscography();
      }
    } else {
      _fetchDiscography();
    }
  }

  void _onScroll() {
    final shouldShow = _scrollController.offset > 280;
    if (shouldShow != _showTitleInAppBar) {
      setState(() => _showTitleInAppBar = shouldShow);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _popularPageController.dispose();
    super.dispose();
  }

  Future<void> _fetchDiscography() async {
    setState(() => _isLoadingDiscography = true);
    try {
      List<ArtistAlbum> albums = [];
      List<ArtistAlbum>? releases;
      List<Track>? topTracks;
      String? headerImage;
      int? listeners;

      if (_directMetadataProviderId() != null && !widget.artistId.startsWith('builtin:')) {
        final providerId = _directMetadataProviderId()!;
        final artistData = await PlatformBridge.getProviderMetadata(
          providerId,
          'artist',
          _metadataResourceId(providerId),
        );
        final albumsList = artistData['albums'] as List<dynamic>? ?? [];
        albums = albumsList
            .map((a) => _parseArtistAlbum(a as Map<String, dynamic>))
            .toList();

        final releasesList = artistData['releases'] as List<dynamic>? ?? [];
        if (releasesList.isNotEmpty) {
          releases = releasesList
              .map((a) => _parseArtistAlbum(a as Map<String, dynamic>))
              .toList();
        }

        final topTracksList = artistData['top_tracks'] as List<dynamic>? ?? [];
        if (topTracksList.isNotEmpty) {
          topTracks = topTracksList
              .map((t) => _parseTrack(t as Map<String, dynamic>))
              .toList();
        }

        final artistInfo = artistData['artist_info'] as Map<String, dynamic>?;
        headerImage =
            artistInfo?['images'] as String? ??
            artistInfo?['header_image'] as String? ??
            artistInfo?['cover_url'] as String? ??
            artistData['header_image'] as String? ??
            artistData['cover_url'] as String? ??
            artistData['image_url'] as String?;
        listeners =
            artistInfo?['listeners'] as int? ?? artistData['listeners'] as int?;
      } else {
        final url = 'https://open.spotify.com/artist/${widget.artistId}';
        final result = await PlatformBridge.handleURLWithExtension(url);

        if (result != null && result['artist'] != null) {
          final artistData = result['artist'] as Map<String, dynamic>;
          final albumsList = artistData['albums'] as List<dynamic>? ?? [];
          albums = albumsList
              .map((a) => _parseArtistAlbum(a as Map<String, dynamic>))
              .toList();

          final topTracksList =
              artistData['top_tracks'] as List<dynamic>? ?? [];
          if (topTracksList.isNotEmpty) {
            topTracks = topTracksList
                .map((t) => _parseTrack(t as Map<String, dynamic>))
                .toList();
          }

          headerImage = artistData['header_image'] as String?;
          listeners = artistData['listeners'] as int?;
        }
      }

      // Fallback: search artist by name across metadata providers (only if no specific source)
      if (albums.isEmpty && widget.artistName.isNotEmpty && (widget.extensionId == null || widget.extensionId!.isEmpty)) {
        final searchResult = await _searchArtistByName();
        if (searchResult != null) {
          albums = searchResult.albums;
          releases = searchResult.releases;
          topTracks = searchResult.topTracks;
          headerImage = searchResult.headerImage ?? headerImage;
          listeners = searchResult.listeners ?? listeners;
        }
      }

      if (albums.isEmpty && topTracks == null) {
        throw StateError('Failed to load artist metadata from any provider');
      }

      final finalHeaderImage =
          headerImage ?? _headerImageUrl ?? widget.headerImageUrl;
      final finalListeners =
          listeners ?? _monthlyListeners ?? widget.monthlyListeners;

      _ArtistCache.set(
        widget.artistId,
        albums: albums,
        releases: releases,
        topTracks: topTracks,
        headerImageUrl: finalHeaderImage,
        monthlyListeners: finalListeners,
      );

      if (mounted) {
        setState(() {
          _albums = albums;
          _releases = releases;
          _topTracks = topTracks;
          _headerImageUrl = finalHeaderImage;
          _monthlyListeners = finalListeners;
          _isLoadingDiscography = false;
        });
      }
    } catch (e) {
      if (mounted) {
        await _loadOfflineArtistData();
      }
    }
  }

  Future<_ArtistSearchResult?> _searchArtistByName() async {
    if (widget.artistName.isEmpty) return null;
    final query = widget.artistName.trim();
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
        // Find an artist result
        final artistResult = results.firstWhere(
          (r) {
            final type = (r['type'] ?? '').toString().toLowerCase();
            final name = (r['name'] ?? '').toString().toLowerCase().trim();
            return type == 'artist' ||
                name == query.toLowerCase() ||
                name.contains(query.toLowerCase());
          },
          orElse: () => results.first,
        );

        final artistId = artistResult['id']?.toString() ??
            artistResult['artist_id']?.toString();
        if (artistId == null || artistId.isEmpty) continue;

        final metadata = await PlatformBridge.getProviderMetadata(
          providerId,
          'artist',
          artistId,
        );

        final albumsList = metadata['albums'] as List<dynamic>? ?? [];
        final albums = albumsList
            .map((a) => _parseArtistAlbum(a as Map<String, dynamic>))
            .toList();

        final releasesList = metadata['releases'] as List<dynamic>? ?? [];
        final releases = releasesList.isNotEmpty
            ? releasesList.map((a) => _parseArtistAlbum(a as Map<String, dynamic>)).toList()
            : null;

        final topTracksList = metadata['top_tracks'] as List<dynamic>? ?? [];
        final topTracks = topTracksList.isNotEmpty
            ? topTracksList.map((t) => _parseTrack(t as Map<String, dynamic>)).toList()
            : null;

        final artistInfo = metadata['artist_info'] as Map<String, dynamic>?;
        final headerImage =
            artistInfo?['images'] as String? ??
            artistInfo?['header_image'] as String? ??
            artistInfo?['cover_url'] as String? ??
            metadata['header_image'] as String? ??
            metadata['cover_url'] as String? ??
            metadata['image_url'] as String?;
        final listeners =
            artistInfo?['listeners'] as int? ?? metadata['listeners'] as int?;

        return _ArtistSearchResult(
          albums: albums,
          releases: releases,
          topTracks: topTracks,
          headerImage: headerImage,
          listeners: listeners,
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Track _parseTrack(Map<String, dynamic> data, {ArtistAlbum? album}) {
    int durationMs = 0;
    final durationValue = data['duration_ms'];
    if (durationValue is int) {
      durationMs = durationValue;
    } else if (durationValue is double) {
      durationMs = durationValue.toInt();
    }

    final spotifyId = (data['spotify_id'] ?? '').toString();
    final nativeId = (data['id'] ?? '').toString();

    return Track(
      id: spotifyId.isNotEmpty ? spotifyId : nativeId,
      name: (data['name'] ?? '').toString(),
      artistName: (data['artists'] ?? data['artist'] ?? '').toString(),
      albumName: (data['album_name'] ?? data['album'] ?? album?.name ?? '')
          .toString(),
      albumArtist: normalizeOptionalString(data['album_artist']?.toString()),
      artistId:
          (data['artist_id'] ?? data['artistId'])?.toString() ??
          widget.artistId,
      albumId: data['album_id']?.toString() ?? album?.id,
      coverUrl: normalizeCoverReference(
        (data['cover_url'] ?? data['images'] ?? album?.coverUrl)?.toString(),
      ),
      isrc: data['isrc']?.toString(),
      duration: (durationMs / 1000).round(),
      trackNumber: data['track_number'] as int?,
      discNumber: data['disc_number'] as int?,
      totalDiscs: data['total_discs'] as int?,
      releaseDate: data['release_date']?.toString(),
      albumType:
          normalizeOptionalString(data['album_type']?.toString()) ??
          album?.albumType,
      totalTracks: data['total_tracks'] as int? ?? album?.totalTracks,
      composer: data['composer']?.toString(),
      source: data['provider_id']?.toString() ?? widget.extensionId,
    );
  }

  ArtistAlbum _parseArtistAlbum(Map<String, dynamic> data) {
    final totalTracksValue = data['total_tracks'];
    final totalTracks = totalTracksValue is int
        ? totalTracksValue
        : int.tryParse(totalTracksValue?.toString() ?? '') ?? 0;

    return ArtistAlbum(
      id: data['id'] as String? ?? '',
      name: (data['name'] ?? data['title'] ?? '').toString(),
      releaseDate: (data['release_date'] ?? '').toString(),
      totalTracks: totalTracks,
      coverUrl: normalizeCoverReference(
        (data['cover_url'] ?? data['images'] ?? data['cover_art'])?.toString(),
      ),
      albumType: (data['album_type'] ?? data['type'] ?? 'album').toString(),
      artists: (data['artists'] ?? data['artist'] ?? widget.artistName)
          .toString(),
      providerId: data['provider_id']?.toString() ?? widget.extensionId,
    );
  }

  Future<void> _loadOfflineArtistData() async {
    final localAlbums = <ArtistAlbum>[];
    final localTracks = <Track>[];
    final seenKeys = <String>{};

    void addTrackIfUnique(Track t) {
      final key = t.isrc ?? t.id;
      if (key.isNotEmpty && !seenKeys.contains(key)) {
        seenKeys.add(key);
        localTracks.add(t);
      }
    }

    final settings = ref.read(settingsProvider);
    final baseDir = settings.downloadDirectory;
    final sanitizedArtist = _sanitizeFolderName(primaryArtistName(widget.artistName));
    final artistDir = Directory(p.join(baseDir, sanitizedArtist));

    if (await artistDir.exists()) {
      final contents = await artistDir.list().toList();
      for (final entity in contents) {
        if (entity is Directory) {
          final name = p.basename(entity.path);
          final subEntities = await entity.list().toList();
          final hasSubDirs = subEntities.any((e) => e is Directory);

          if (hasSubDirs) {
            final albumName = name;
            final albumCover = File(p.join(entity.path, 'cover.jpg'));
            String? coverPath;
            if (await albumCover.exists()) {
              coverPath = albumCover.path;
            }

            final albumTracks = <Track>[];
            for (final songEntity in subEntities) {
              if (songEntity is Directory) {
                final songName = p.basename(songEntity.path);
                final songFiles = await songEntity.list().toList();
                String? audioPath;
                String? songCoverPath;
                
                for (final file in songFiles) {
                  if (file is File) {
                    final ext = p.extension(file.path).toLowerCase();
                    if (['.flac', '.mp3', '.m4a', '.opus', '.wav'].contains(ext)) {
                      audioPath = file.path;
                    } else if ((ext == '.jpg' || ext == '.png') && songCoverPath == null) {
                      songCoverPath = file.path;
                    }
                  }
                }

                if (audioPath != null) {
                  final track = Track(
                    id: 'local_${songName.hashCode}',
                    name: songName,
                    artistName: widget.artistName,
                    albumName: albumName,
                    coverUrl: coverPath ?? songCoverPath,
                    duration: 0,
                  );
                  albumTracks.add(track);
                  addTrackIfUnique(track);
                }
              }
            }

            if (albumTracks.isNotEmpty) {
              localAlbums.add(ArtistAlbum(
                id: 'local_album:${albumName.toLowerCase()}',
                name: albumName,
                releaseDate: '',
                totalTracks: albumTracks.length,
                coverUrl: coverPath,
                albumType: 'album',
                artists: widget.artistName,
              ));
              _localAlbumTracksMap['local_album:${albumName.toLowerCase()}'] = albumTracks;
            }
          } else {
            final songFiles = await entity.list().toList();
            String? audioPath;
            String? coverPath;

            for (final file in songFiles) {
              if (file is File) {
                final ext = p.extension(file.path).toLowerCase();
                if (['.flac', '.mp3', '.m4a', '.opus', '.wav'].contains(ext)) {
                  audioPath = file.path;
                } else if ((ext == '.jpg' || ext == '.png') && coverPath == null) {
                  coverPath = file.path;
                }
              }
            }

            if (audioPath != null) {
              final track = Track(
                id: 'local_single_${name.hashCode}',
                name: name,
                artistName: widget.artistName,
                albumName: name,
                coverUrl: coverPath,
                duration: 0,
              );
              addTrackIfUnique(track);
            }
          }
        }
      }
    }

    final singlesTracks = localTracks
        .where((t) => t.albumName == t.name)
        .toList();
    if (singlesTracks.isNotEmpty && !localAlbums.any((a) => a.id == 'local_album:singles')) {
      localAlbums.add(ArtistAlbum(
        id: 'local_album:singles',
        name: 'Singles',
        releaseDate: '',
        totalTracks: singlesTracks.length,
        coverUrl: singlesTracks.first.coverUrl,
        albumType: 'single',
        artists: widget.artistName,
      ));
      _localAlbumTracksMap['local_album:singles'] = singlesTracks;
    }

    final lovedState = ref.read(libraryCollectionsProvider);
    for (final entry in lovedState.loved) {
      if (_matchesArtist(entry.track)) {
        final track = entry.track;
        final enrichedTrack = entry.audioPath != null || entry.coverPath != null
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
    for (final playlist in lovedState.playlists) {
      for (final entry in playlist.tracks) {
        if (_matchesArtist(entry.track)) {
          final track = entry.track;
          final enrichedTrack = entry.audioPath != null || entry.coverPath != null
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

    final historyRows = await HistoryDatabase.instance.getArtistTracks(widget.artistName);
    for (final row in historyRows) {
      final item = DownloadHistoryItem.fromJson(row);
      final existingAlbum = localAlbums.where(
        (a) => a.name.toLowerCase() == item.albumName.toLowerCase()
      ).firstOrNull;
      if (existingAlbum == null && item.albumName.isNotEmpty) {
        localAlbums.add(ArtistAlbum(
          id: 'local_album:${item.albumName.toLowerCase()}',
          name: item.albumName,
          releaseDate: item.releaseDate ?? '',
          totalTracks: 0,
          coverUrl: item.coverUrl ?? widget.coverUrl,
          albumType: 'album',
          artists: item.artistName,
          providerId: item.service,
        ));
      }
      addTrackIfUnique(Track(
        id: item.spotifyId ?? 'hist_${item.id}',
        name: item.trackName,
        artistName: item.artistName,
        albumName: item.albumName,
        albumArtist: item.albumArtist,
        coverUrl: item.coverUrl ?? widget.coverUrl,
        isrc: item.isrc,
        duration: item.duration ?? 0,
        trackNumber: item.trackNumber,
        discNumber: item.discNumber,
        totalDiscs: item.totalDiscs,
        totalTracks: item.totalTracks,
        releaseDate: item.releaseDate,
        source: item.service,
      ));
    }

    // Fallback: look for local cover.jpg for albums that have remote or no cover
    if (localAlbums.isNotEmpty) {
      final downloadDir = Directory(settings.downloadDirectory);
      if (await downloadDir.exists()) {
        final artistDirName = _sanitizeFolderName(primaryArtistName(widget.artistName));
        final artistDir = Directory(p.join(downloadDir.path, artistDirName));
        if (await artistDir.exists()) {
          final contents = await artistDir.list().toList();
          for (final entity in contents) {
            if (entity is Directory) {
              final albumName = p.basename(entity.path);
              final coverFile = File(p.join(entity.path, 'cover.jpg'));
              if (await coverFile.exists()) {
                final matchingAlbum = localAlbums.where(
                  (a) => _sanitizeFolderName(a.name).toLowerCase() == albumName.toLowerCase(),
                ).firstOrNull;
                if (matchingAlbum != null && matchingAlbum.coverUrl == null) {
                  final idx = localAlbums.indexOf(matchingAlbum);
                  localAlbums[idx] = ArtistAlbum(
                    id: matchingAlbum.id,
                    name: matchingAlbum.name,
                    releaseDate: matchingAlbum.releaseDate,
                    totalTracks: matchingAlbum.totalTracks,
                    coverUrl: coverFile.path,
                    albumType: matchingAlbum.albumType,
                    artists: matchingAlbum.artists,
                    providerId: matchingAlbum.providerId,
                  );
                }
              }
            }
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _topTracks = localTracks;
        if (_albums == null || _albums!.isEmpty) {
          _albums = localAlbums;
        }
        _isLoadingDiscography = false;
      });
    }
  }


  String _sanitizeFolderName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _matchesArtist(Track track) {
    return track.artistName == widget.artistName || 
           track.albumArtist == widget.artistName;
  }

  void _ensureAlbumBuckets(List<ArtistAlbum> albums) {
    if (identical(albums, _albumBucketSource)) return;
    _albumBucketSource = albums;
    _albumsOnlyBucket = albums
        .where((a) => a.albumType == 'album')
        .toList(growable: false);
    _singlesBucket = albums
        .where((a) => a.albumType == 'single' || a.albumType == 'ep')
        .toList(growable: false);
    _compilationsBucket = albums
        .where((a) => a.albumType == 'compilation')
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final albums = _albums ?? [];
    _ensureAlbumBuckets(albums);
    final releases = _releases ?? const <ArtistAlbum>[];
    final albumsOnly = _albumsOnlyBucket;
    final singles = _singlesBucket;
    final compilations = _compilationsBucket;

    final hasDiscography =
        !_isLoadingDiscography && _error == null && albums.isNotEmpty;

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            ReactiveGlassBackground(
              coverUrl: _headerImageUrl ?? widget.headerImageUrl ?? widget.coverUrl,
              child: const SizedBox.expand(),
            ),
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                _buildHeader(
                  context,
                  colorScheme,
                  albums: albums,
                  hasDiscography: hasDiscography,
                ),
                if (_isLoadingDiscography)
                  SliverToBoxAdapter(
                    child: ArtistScreenSkeleton(
                      showCoverHeader:
                          (_headerImageUrl ??
                              widget.headerImageUrl ??
                              widget.coverUrl) ==
                          null,
                      showPopularSection:
                          !widget.artistId.startsWith('deezer:') &&
                          !widget.artistId.startsWith('qobuz:') &&
                          !widget.artistId.startsWith('tidal:'),
                    ),
                  ),
                if (_error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildErrorWidget(_error!, colorScheme),
                    ),
                  ),
                if (!_isLoadingDiscography && _error == null) ...[
                  if (_topTracks != null && _topTracks!.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildPopularSection(colorScheme),
                    ),
                  if (releases.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildAlbumSection(
                        'Releases',
                        releases,
                        colorScheme,
                      ),
                    ),
                  if (albumsOnly.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildAlbumSection(
                        context.l10n.artistAlbums,
                        albumsOnly,
                        colorScheme,
                      ),
                    ),
                  if (singles.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildAlbumSection(
                        context.l10n.artistSingles,
                        singles,
                        colorScheme,
                        showTypeBadge: true,
                      ),
                    ),
                  if (compilations.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildAlbumSection(
                        context.l10n.artistCompilations,
                        compilations,
                        colorScheme,
                      ),
                    ),
                ],
                SliverToBoxAdapter(
                  child: SizedBox(height: _isSelectionMode ? 120 : 32),
                ),
              ],
            ),
            if (_isSelectionMode)
              _buildSelectionBar(context, colorScheme, albums),
          ],
        ),
      ),
    );
  }

  void _exitSelectionMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isSelectionMode = false;
      _selectedAlbumIds.clear();
    });
  }

  void _enterSelectionMode(String albumId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedAlbumIds.add(albumId);
    });
  }

  void _toggleAlbumSelection(String albumId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedAlbumIds.contains(albumId)) {
        _selectedAlbumIds.remove(albumId);
        if (_selectedAlbumIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedAlbumIds.add(albumId);
      }
    });
  }

  void _selectAll(List<ArtistAlbum> albums) {
    setState(() {
      _selectedAlbumIds.addAll(albums.map((a) => a.id));
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedAlbumIds.clear();
    });
  }

  Widget _buildSelectionBar(
    BuildContext context,
    ColorScheme colorScheme,
    List<ArtistAlbum> allAlbums,
  ) {
    final allSelected = _selectedAlbumIds.length == allAlbums.length;
    final selectedCount = _selectedAlbumIds.length;
    final selectedAlbums = allAlbums
        .where((a) => _selectedAlbumIds.contains(a.id))
        .toList();
    final totalTracks = selectedAlbums.fold<int>(
      0,
      (sum, a) => sum + a.totalTracks,
    );
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final compactLayout =
        MediaQuery.sizeOf(context).width < 430 || textScale > 1.15;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: compactLayout
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: _exitSelectionMode,
                            icon: const Icon(Icons.close),
                            tooltip: context.l10n.dialogCancel,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  context.l10n.discographySelectedCount(
                                    selectedCount,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (selectedCount > 0)
                                  Text(
                                    context.l10n.tracksCount(totalTracks),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: allSelected
                                  ? _deselectAll
                                  : () => _selectAll(allAlbums),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  allSelected
                                      ? context.l10n.actionDeselect
                                      : context.l10n.actionSelectAll,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: selectedCount > 0
                                  ? () => _downloadSelectedAlbums(
                                      context,
                                      selectedAlbums,
                                    )
                                  : null,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  context.l10n.discographyDownloadSelected,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      IconButton(
                        onPressed: _exitSelectionMode,
                        icon: const Icon(Icons.close),
                        tooltip: context.l10n.dialogCancel,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.l10n.discographySelectedCount(
                                selectedCount,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (selectedCount > 0)
                              Text(
                                context.l10n.tracksCount(totalTracks),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: allSelected
                            ? _deselectAll
                            : () => _selectAll(allAlbums),
                        child: Text(
                          allSelected
                              ? context.l10n.actionDeselect
                              : context.l10n.actionSelectAll,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: selectedCount > 0
                            ? () => _downloadSelectedAlbums(
                                context,
                                selectedAlbums,
                              )
                            : null,
                        icon: const Icon(Icons.download, size: 18),
                        label: Text(context.l10n.discographyDownloadSelected),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  void _showDiscographyOptions(
    BuildContext context,
    ColorScheme colorScheme,
    List<ArtistAlbum> albums,
  ) {
    final albumsOnly = albums.where((a) => a.albumType == 'album').toList();
    final singles = albums
        .where((a) => a.albumType == 'single' || a.albumType == 'ep')
        .toList();

    final totalTracks = albums.fold<int>(0, (sum, a) => sum + a.totalTracks);
    final albumTracks = albumsOnly.fold<int>(
      0,
      (sum, a) => sum + a.totalTracks,
    );
    final singleTracks = singles.fold<int>(0, (sum, a) => sum + a.totalTracks);

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Row(
                  children: [
                    Icon(Icons.download, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      context.l10n.discographyDownload,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (albums.isNotEmpty)
                _DiscographyOptionTile(
                  icon: Icons.library_music,
                  title: context.l10n.discographyDownloadAll,
                  subtitle: context.l10n.discographyDownloadAllSubtitle(
                    totalTracks,
                    albums.length,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _downloadAlbums(context, albums);
                  },
                ),
              if (albumsOnly.isNotEmpty)
                _DiscographyOptionTile(
                  icon: Icons.album,
                  title: context.l10n.discographyAlbumsOnly,
                  subtitle: context.l10n.discographyAlbumsOnlySubtitle(
                    albumTracks,
                    albumsOnly.length,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _downloadAlbums(context, albumsOnly);
                  },
                ),
              if (singles.isNotEmpty)
                _DiscographyOptionTile(
                  icon: Icons.music_note,
                  title: context.l10n.discographySinglesOnly,
                  subtitle: context.l10n.discographySinglesOnlySubtitle(
                    singleTracks,
                    singles.length,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _downloadAlbums(context, singles);
                  },
                ),
              _DiscographyOptionTile(
                icon: Icons.checklist,
                title: context.l10n.discographySelectAlbums,
                subtitle: context.l10n.discographySelectAlbumsSubtitle,
                onTap: () {
                  Navigator.pop(context);
                  _enterSelectionMode(albums.first.id);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadAlbums(
    BuildContext context,
    List<ArtistAlbum> albums,
  ) async {
    final settings = ref.read(settingsProvider);
    if (!settings.isPremium && settings.premiumUntil == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Suscríbete a premium para descargar la discografía completa'),
        ),
      );
      return;
    }
    if (settings.askQualityBeforeDownload) {
      DownloadServicePicker.show(
        context,
        recommendedService: _recommendedDownloadService(),
        onSelect: (quality, service) {
          _fetchAndQueueAlbums(albums, service, quality);
        },
      );
    } else {
      _fetchAndQueueAlbums(albums, settings.defaultService, null);
    }
  }

  Future<void> _downloadSelectedAlbums(
    BuildContext context,
    List<ArtistAlbum> albums,
  ) async {
    _exitSelectionMode();
    await _downloadAlbums(context, albums);
  }

  Future<void> _toggleFavoriteArtist(BuildContext context) async {
    final providerId = _directMetadataProviderId();
    final imageUrl =
        _headerImageUrl ?? widget.headerImageUrl ?? widget.coverUrl;
    final added = await ref
        .read(libraryCollectionsProvider.notifier)
        .toggleFavoriteArtist(
          artistId: _metadataResourceId(providerId ?? ''),
          providerId: providerId,
          name: widget.artistName,
          imageUrl: imageUrl,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? context.l10n.collectionAddedToFavoriteArtists(widget.artistName)
              : context.l10n.collectionRemovedFromFavoriteArtists(
                  widget.artistName,
                ),
        ),
      ),
    );
  }

  Future<void> _fetchAndQueueAlbums(
    List<ArtistAlbum> albums,
    String service,
    String? qualityOverride,
  ) async {
    if (_isFetchingDiscography) return;

    setState(() => _isFetchingDiscography = true);

    if (!mounted) {
      setState(() => _isFetchingDiscography = false);
      return;
    }

    final progressDialogKey = GlobalKey<_FetchingProgressDialogState>();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _FetchingProgressDialog(
        key: progressDialogKey,
        totalAlbums: albums.length,
        onCancel: () {
          setState(() => _isFetchingDiscography = false);
          Navigator.pop(ctx);
        },
      ),
    );

    final allTracks = <Track>[];
    int fetchedCount = 0;
    int failedCount = 0;

    for (final album in albums) {
      if (!_isFetchingDiscography) break;

      try {
        final tracks = await _fetchAlbumTracks(album);
        allTracks.addAll(tracks);
      } catch (e) {
        failedCount++;
      }

      fetchedCount++;

      if (mounted) {
        progressDialogKey.currentState?.updateProgress(
          fetchedCount,
          albums.length,
        );
      }
    }

    setState(() => _isFetchingDiscography = false);

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (failedCount > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.discographyFailedToFetch)),
      );
    }

    if (allTracks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.discographyNoAlbums)),
        );
      }
      return;
    }

    final historyLookups = allTracks
        .map(historyLookupForTrack)
        .toList(growable: false);
    final existingHistoryKeys = await ref.read(
      downloadHistoryBatchExistsProvider(
        HistoryBatchLookupRequest(historyLookups),
      ).future,
    );
    final tracksToQueue = <Track>[];
    int skippedCount = 0;

    for (var i = 0; i < allTracks.length; i++) {
      final track = allTracks[i];
      final isDownloaded = existingHistoryKeys.contains(
        historyLookups[i].lookupKey,
      );

      if (!isDownloaded) {
        tracksToQueue.add(track);
      } else {
        skippedCount++;
      }
    }

    if (tracksToQueue.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.discographySkippedDownloaded(0, skippedCount),
            ),
          ),
        );
      }
      return;
    }

    ref
        .read(downloadQueueProvider.notifier)
        .addMultipleToQueue(
          tracksToQueue,
          service,
          qualityOverride: qualityOverride,
        );

    if (mounted) {
      final message = skippedCount > 0
          ? context.l10n.discographySkippedDownloaded(
              tracksToQueue.length,
              skippedCount,
            )
          : context.l10n.discographyAddedToQueue(tracksToQueue.length);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: context.l10n.snackbarViewQueue,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  Future<List<Track>> _fetchAlbumTracks(ArtistAlbum album) async {
    final providerId = album.providerId;
    if (providerId != null && providerId.isNotEmpty) {
      final resourceId = _stripPrefixedResourceId(album.id);
      final metadata = await PlatformBridge.getProviderMetadata(
        providerId,
        'album',
        resourceId,
      );
      if (metadata['track_list'] != null) {
        final tracksList = metadata['track_list'] as List<dynamic>;
        return tracksList
            .map((t) => _parseTrack(t as Map<String, dynamic>, album: album))
            .toList();
      }
    } else {
      final url = 'https://open.spotify.com/album/${album.id}';
      final result = await PlatformBridge.handleURLWithExtension(url);
      if (result != null && result['tracks'] != null) {
        final tracksList = result['tracks'] as List<dynamic>;
        return tracksList
            .map((t) => _parseTrack(t as Map<String, dynamic>, album: album))
            .toList();
      }
    }
    return [];
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme colorScheme, {
    required List<ArtistAlbum> albums,
    required bool hasDiscography,
  }) {
    String? imageUrl = _headerImageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      imageUrl = widget.headerImageUrl;
    }
    if (imageUrl == null || imageUrl.isEmpty) {
      imageUrl = widget.coverUrl;
    }

    final hasValidImage =
        imageUrl != null &&
        imageUrl.isNotEmpty &&
        Uri.tryParse(imageUrl)?.hasAuthority == true;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    String? listenersText;
    final listeners = _monthlyListeners ?? widget.monthlyListeners;
    if (listeners != null && listeners > 0) {
      final formatter = NumberFormat.compact();
      listenersText = context.l10n.artistMonthlyListeners(
        formatter.format(listeners),
      );
    }

    final favoriteProviderId = _directMetadataProviderId();
    final favoriteArtistId = _metadataResourceId(favoriteProviderId ?? '');
    final isFavoriteArtist = ref.watch(
      libraryCollectionsProvider.select(
        (state) => state.isFavoriteArtist(
          artistId: favoriteArtistId,
          providerId: favoriteProviderId,
          name: widget.artistName,
        ),
      ),
    );

    return SliverAppBar(
      expandedHeight: hasDiscography ? 420 : 380,
      pinned: true,
      stretch: true,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      title: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _showTitleInAppBar ? 1.0 : 0.0,
        child: Text(
          widget.artistName,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.none,
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (hasValidImage)
              CachedCoverImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                memCacheWidth: 800,
                placeholder: (context, url) =>
                    Container(color: colorScheme.surfaceContainerHighest),
                errorWidget: (context, url, error) => Container(
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.person,
                    size: 80,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Container(
                color: colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.person,
                  size: 80,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.7),
                    isDark
                        ? colorScheme.surface
                        : Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.5, 0.75, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.artistName,
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    offset: const Offset(0, 1),
                                    blurRadius: 4,
                                    color: Colors.black.withValues(alpha: 0.5),
                                  ),
                                ],
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (listenersText != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            listenersText,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      offset: const Offset(0, 1),
                                      blurRadius: 2,
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!_isSelectionMode) ...[
                    const SizedBox(width: 12),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () => _toggleFavoriteArtist(context),
                        icon: Icon(
                          isFavoriteArtist
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 26,
                        ),
                        color: isFavoriteArtist
                            ? colorScheme.error
                            : Colors.black87,
                        tooltip: isFavoriteArtist
                            ? context.l10n.artistOptionRemoveFromFavorites
                            : context.l10n.artistOptionAddToFavorites,
                      ),
                    ),
                  ],
                  if (hasDiscography && !_isSelectionMode) ...[
                    const SizedBox(width: 12),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () => _showDiscographyOptions(
                          context,
                          colorScheme,
                          albums,
                        ),
                        icon: const Icon(Icons.download_rounded, size: 26),
                        color: Colors.black87,
                        tooltip: context.l10n.discographyDownload,
                      ),
                    ),
                    if (_topTracks != null && _topTracks!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () => showTrackSelectionForPlaylist(
                            context, ref,
                            title: context.l10n.tooltipAddToPlaylist,
                            subtitle: widget.artistName,
                            tracks: _topTracks!,
                          ),
                          icon: const Icon(Icons.playlist_add, size: 22),
                          color: Colors.black87,
                          tooltip: context.l10n.tooltipAddToPlaylist,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
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

  Widget _buildPopularSection(ColorScheme colorScheme) {
    if (_topTracks == null || _topTracks!.isEmpty) {
      return const SizedBox.shrink();
    }

    final tracks = _topTracks!;
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
    const tracksPerPage = 5;
    final pageCount = (tracks.length / tracksPerPage).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 24, 8, 12),
          child: Text(
            context.l10n.artistPopular,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: tracksPerPage * 66.0,
          child: PageView.builder(
            controller: _popularPageController,
            itemCount: pageCount,
            onPageChanged: (page) {
              setState(() {
                _popularCurrentPage = page;
              });
            },
            itemBuilder: (context, pageIndex) {
              final startIndex = pageIndex * tracksPerPage;
              final endIndex = (startIndex + tracksPerPage).clamp(
                0,
                tracks.length,
              );
              final pageTracks = tracks.sublist(startIndex, endIndex);

              return Column(
                children: pageTracks.asMap().entries.map((entry) {
                  final globalIndex = startIndex + entry.key;
                  return _buildPopularTrackItem(
                    globalIndex + 1,
                    entry.value,
                    colorScheme,
                    existingHistoryKeys.contains(
                      historyLookups[globalIndex].lookupKey,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
        if (pageCount > 1)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(pageCount, (index) {
                  final isActive = _popularCurrentPage == index;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 8 : 6,
                    height: isActive ? 8 : 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    ),
                  );
                }),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPopularTrackItem(
    int rank,
    Track track,
    ColorScheme colorScheme,
    bool isInHistory,
  ) {
    return Consumer(
      builder: (context, ref, child) {
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
        final isDownloaded = isInHistory || isInLocalLibrary;
        final downloadProgress = isQueued ? queueItem.progress : (isDownloaded ? 1.0 : 0.0);

        return TrackCard(
          track: track,
          showHeartButton: true,
          showInfoButton: true,
          showQualityBadge: false,
          showStatusDot: true,

          downloadProgress: downloadProgress,
          coverSize: 48,
          onTap: () => _handlePopularTrackTap(track, isQueued: isQueued),
        );
      },
    );
  }

  void _handlePopularTrackTap(Track track, {required bool isQueued}) async {
    if (isQueued) return;

    final audioPath = ref.read(libraryCollectionsProvider).findAudioPath(track);
    final playedLocal = await _playLocalIfAvailable(track, audioPath: audioPath);
    if (playedLocal) return;

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
  }

  Future<bool> _playLocalIfAvailable(Track track, {String? audioPath}) async {
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

    final historyNotifier = ref.read(downloadHistoryProvider.notifier);

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.snackbarCannotOpenFile('$e'))),
        );
      }
      return true;
    }

    return false;
  }

  void _downloadTrack(Track track) {
    final settings = ref.read(settingsProvider);
    if (!settings.isPremium && settings.premiumUntil == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Suscríbete a premium para descargar'),
        ),
      );
      return;
    }
    ref.read(settingsProvider.notifier).setHasSearchedBefore();

    void enqueue(String service, {String? quality}) {
      ref
          .read(downloadQueueProvider.notifier)
          .addToQueue(track, service, qualityOverride: quality);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.snackbarAddedToQueue(track.name)),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    if (settings.askQualityBeforeDownload) {
      DownloadServicePicker.show(
        context,
        recommendedService: _recommendedDownloadService(),
        onSelect: (quality, service) {
          if (!mounted) return;
          enqueue(service, quality: quality);
        },
      );
      return;
    }

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
    enqueue(service);
  }

  Widget _buildAlbumSection(
    String title,
    List<ArtistAlbum> albums,
    ColorScheme colorScheme, {
    bool showTypeBadge = false,
  }) {
    final sectionHeight = _artistAlbumSectionHeight();
    final tileSize = _artistAlbumTileSize();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 24, 8, 12),
          child: Text(
            '$title (${albums.length})',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: sectionHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              return KeyedSubtree(
                key: ValueKey(album.id),
                child: _buildAlbumCard(
                  album,
                  colorScheme,
                  tileSize: tileSize,
                  sectionHeight: sectionHeight,
                  showTypeBadge: showTypeBadge,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumCard(
    ArtistAlbum album,
    ColorScheme colorScheme, {
    required double tileSize,
    required double sectionHeight,
    bool showTypeBadge = false,
  }) {
    return AlbumCard(
      albumName: album.name,
      artistName: album.totalTracks > 0
          ? '${album.releaseDate.length >= 4 ? album.releaseDate.substring(0, 4) : album.releaseDate} ${context.l10n.tracksCount(album.totalTracks)}'
          : album.releaseDate.length >= 4
          ? album.releaseDate.substring(0, 4)
          : album.releaseDate,
      coverUrl: album.coverUrl,
      trackCount: album.totalTracks,
      width: tileSize,
      height: sectionHeight,
      showSelectionCheckbox: _isSelectionMode,
      isSelected: _selectedAlbumIds.contains(album.id),
      showTypeBadge: showTypeBadge,
      albumType: album.albumType,
      onTap: () {
        if (_isSelectionMode) {
          _toggleAlbumSelection(album.id);
        } else {
          _navigateToAlbum(album);
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) {
          _enterSelectionMode(album.id);
        }
      },
    );
  }

  void _navigateToAlbum(ArtistAlbum album) {
    ref.read(settingsProvider.notifier).setHasSearchedBefore();

    if (album.id.startsWith('local_album:')) {
      final tracks = _localAlbumTracksMap[album.id];
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => AlbumScreen(
            albumId: album.id,
            albumName: album.name,
            coverUrl: album.coverUrl,
            tracks: tracks,
            artistName: widget.artistName,
          ),
        ),
      );
    } else if (album.providerId != null && album.providerId!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => ExtensionAlbumScreen(
            extensionId: album.providerId!,
            albumId: album.id,
            albumName: album.name,
            coverUrl: album.coverUrl,
            initialAlbumType: album.albumType,
            initialTotalTracks: album.totalTracks,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => AlbumScreen(
            albumId: album.id,
            albumName: album.name,
            coverUrl: album.coverUrl,
            artistName: widget.artistName,
          ),
        ),
      );
    }
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

class _DiscographyOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DiscographyOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: colorScheme.onPrimaryContainer, size: 24),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
      ),
      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

class _FetchingProgressDialog extends StatefulWidget {
  final int totalAlbums;
  final VoidCallback onCancel;

  const _FetchingProgressDialog({
    super.key,
    required this.totalAlbums,
    required this.onCancel,
  });

  @override
  State<_FetchingProgressDialog> createState() =>
      _FetchingProgressDialogState();
}

class _FetchingProgressDialogState extends State<_FetchingProgressDialog> {
  int _current = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _total = widget.totalAlbums;
  }

  void updateProgress(int current, int total) {
    if (mounted) {
      setState(() {
        _current = current;
        _total = total;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = _total > 0 ? _current / _total : 0.0;

    return AlertDialog(
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress > 0 ? progress : null,
                  strokeWidth: 4,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
                Icon(Icons.library_music, color: colorScheme.primary, size: 24),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.discographyFetchingTracks,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.discographyFetchingAlbum(_current, _total),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              backgroundColor: colorScheme.surfaceContainerHighest,
              minHeight: 6,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: Text(context.l10n.dialogCancel),
        ),
      ],
    );
  }
}


