import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import '../../../backend/cache/detail_cache.dart';
import '../../../backend/cache/detail_memory_cache.dart';
import '../../../backend/cache/download_cache.dart';
import '../../../backend/cache/playback_cache.dart';
import '../../../backend/cache/settings_cache.dart';
import '../../../backend/rpc/backend_service.dart';
import '../../shared/detail/load_utils.dart';
import '../../shared/utils/responsive.dart';
import '../../shared/utils/download_strategy.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/detail_models.dart';
import '../../shared/models/feed_models.dart';
import '../../../backend/services/like_cubit.dart';
import '../../../backend/services/download_cubit.dart';
import '../../../backend/services/queue_cubit.dart';
import '../../shared/widgets/track_card.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/download_indicator.dart';
import '../../shared/widgets/download_options_sheet.dart';
import '../../../backend/services/connectivity_service.dart';
import '../../../injection.dart';

class AlbumDetailPage extends StatefulWidget {
  final String albumId;
  final String source;
  final String? coverUrl;
  const AlbumDetailPage({super.key, required this.albumId, this.source = '', this.coverUrl});

  @override
  State<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  AlbumDetail? _album;
  bool _loading = true;
  bool _error = false;
  bool _isOnline = true;
  /// Best available cover URL for the album, resolved from likes or album data.
  /// Set during build(), reused in _downloadAll() to ensure tracks use the
  /// same cover URL that's actually displayed on the screen.
  String? _resolvedAlbumCover;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    _isOnline = await ConnectivityService.isOnline();

    final memCache = sl<DetailMemoryCache>();
    final pb = sl<PlaybackCache>();
    final cache = sl<DetailCache>();
    final backend = sl<BackendService>();

    AlbumDetail? detail;

    // Session memory cache (fastest — avoids any I/O within same session)
    detail = memCache.getAlbum(widget.albumId);
    if (detail != null && detail.tracks.isNotEmpty) {
      if (mounted) setState(() { _album = detail; _loading = false; });
      return;
    }

    // Try local Drift DB first
    detail = await pb.getAlbumDetailLocal(widget.albumId);
    if (detail != null && detail.tracks.isNotEmpty) {
      if (mounted) setState(() { _album = detail; _loading = false; });
      memCache.setAlbum(widget.albumId, detail);
      if (_isOnline) _refreshFromApi(cache, backend, pb);
      return;
    }

    // No local data: try DetailCache then API
    try {
      detail = await loadDetailWithFallback(
        id: widget.albumId,
        source: widget.source,
        getLocal: (id) => cache.getAlbumDetail(id),
        fetchRemote: (id, src) => backend.fetchAlbumDetail(id, src),
        fromJson: AlbumDetail.fromJson,
      );
      if (detail == null) {
        final local = await pb.getAlbumDetailLocal(widget.albumId);
        if (local != null && local.tracks.isNotEmpty) detail = local;
      }
      if (detail != null) memCache.setAlbum(widget.albumId, detail);
    } catch (_) {}

    detail ??= await _buildFromBatch();

    if (mounted) setState(() { _album = detail; _loading = false; _error = detail == null; });
  }

  Future<void> _refreshFromApi(DetailCache cache, BackendService backend, PlaybackCache pb) async {
    try {
      final json = await backend.fetchAlbumDetail(widget.albumId, widget.source);
      if (json.isNotEmpty && json != '{}') {
        final fresh = AlbumDetail.fromJson(jsonDecode(json) as Map<String, dynamic>);
        sl<DetailMemoryCache>().setAlbum(widget.albumId, fresh);
        await pb.syncAlbumDetail(fresh, source: widget.source);
        await cache.setAlbumDetail(widget.albumId, json);
        if (mounted) setState(() { _album = fresh; _error = false; });
      }
    } catch (_) {}
  }

  /// Build an [AlbumDetail] from batch download data when API/local cache unavailable.
  Future<AlbumDetail?> _buildFromBatch() async {
    final dlCache = sl<DownloadCache>();
    var batch = await dlCache.getBatchByItem('album', widget.albumId, widget.source);
    if (batch == null && widget.source.isNotEmpty) {
      batch = await dlCache.getBatchByItem('album', widget.albumId, '');
    }
    if (batch == null || batch.trackIds == null || batch.trackIds!.isEmpty) return null;

    final List<dynamic> rawIds;
    try { rawIds = jsonDecode(batch.trackIds!) as List<dynamic>; } catch (_) { return null; }

    final history = jsonDecode(await dlCache.getDownloadHistory()) as List<dynamic>;
    final trackMap = <String, Map<String, dynamic>>{};
    for (final entry in history) {
      final m = entry as Map<String, dynamic>;
      trackMap[(m['id'] as String?)?.toLowerCase() ?? ''] = m;
    }

    final tracks = <DetailTrack>[];
    for (final raw in rawIds) {
      final stateKey = raw as String;
      final parts = stateKey.split('_');
      if (parts.length < 3) continue;
      final normalizedId = parts.sublist(1, parts.length - 1).join('_');
      final meta = trackMap[normalizedId] ?? trackMap[stateKey.toLowerCase()];
      tracks.add(DetailTrack(
        trackId: meta?['id'] as String? ?? normalizedId,
        name: meta?['track_name'] as String? ?? normalizedId,
        durationMs: (meta?['duration'] as num?)?.toInt() ?? 0,
        isrc: meta?['isrc'] as String? ?? '',
        coverUrl: meta?['cover_url'] as String? ?? '',
        coverPath: meta?['cover_path'] as String? ?? '',
        artistName: meta?['artist_name'] as String? ?? '',
        albumName: meta?['album_name'] as String? ?? batch.name,
        provider: meta?['providerSource'] as String? ?? widget.source,
      ));
    }

    if (tracks.isEmpty) return null;
    return AlbumDetail(
      id: batch.itemId ?? widget.albumId,
      name: batch.name ?? '',
      artistName: tracks.first.artistName,
      totalTracks: tracks.length,
      coverUrl: widget.coverUrl,
      tracks: tracks,
    );
  }

  Future<void> _downloadAll() async {
    if (_album == null || _album!.tracks.isEmpty) return;
    final dlCubit = context.read<DownloadCubit>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = await sl<SettingsCache>().getDownloadSettings();
    final src = widget.source.isNotEmpty ? widget.source : (_album!.tracks.first.provider ?? '');
    final album = _album!;

    final tracks = album.tracks.map((t) => <String, dynamic>{
      'track_id': t.trackId,
      'track_title': t.name,
      'artist_name': (t.artistName?.isNotEmpty == true) ? t.artistName! : ((album.artistName?.isNotEmpty == true) ? album.artistName! : ''),
      'album_name': (t.albumName?.isNotEmpty == true) ? t.albumName! : album.name,
      'source': src,
      'isrc': t.isrc,
      'duration_ms': t.durationMs,
      'cover_url': (t.coverUrl?.isNotEmpty == true) ? t.coverUrl! : (_resolvedAlbumCover ?? album.coverUrl ?? widget.coverUrl),
    }).toList();

    // Show quality selector before starting batch
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DownloadOptionsSheet(
        item: FeedItem(
          id: album.id, type: 'album', name: album.name,
          artists: album.artistName,           coverUrl: _resolvedAlbumCover ?? album.coverUrl ?? widget.coverUrl,
          source: src,
        ),
        isDark: isDark,
        dlSettings: settings,
        onQualitySelected: (quality) {
          dlCubit.startAlbumDownload(album.id, tracks,
            settings: settings, source: src, qualityOverride: quality);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? Colors.white : Colors.black;
    final loc = AppLocalizations.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.setup.searchAlbums)),
        body: Center(child: CircularProgressIndicator(strokeWidth: 2, color: onBg.withValues(alpha: 0.3))),
      );
    }
    if (_album == null) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.setup.searchAlbums)),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(loc.setup.feedEmpty,
              style: TextStyle(color: onBg.withValues(alpha: 0.4))),
            if (_error)
              TextButton.icon(
                onPressed: _load,
                icon: Icon(Icons.refresh, size: 18, color: onBg.withValues(alpha: 0.6)),
                label: Text(loc.setup.retry, style: TextStyle(color: onBg.withValues(alpha: 0.6))),
              ),
          ]),
        ),
      );
    }

    final album = _album!;
    final likedCubit = context.watch<LikeCubit>();
    final dlCubit = context.watch<DownloadCubit>();
    final src = widget.source.isNotEmpty ? widget.source : (album.tracks.isNotEmpty ? (album.tracks.first.provider ?? '') : '');
    final batchKey = 'album_${normalizeTrackId(album.id)}_$src';
    final batchState = dlCubit.downloadStateFor(batchKey);

    // Resolve cover: try liked album by ID first (for local covers), then fingerprint match, then fallbacks
    final likedAlbum = likedCubit.state.allLiked[album.id];
    final likedAlbumCover = likedAlbum?.localCoverPath ?? likedAlbum?.coverUrl;
    final albumCover = likedAlbumCover ?? likedCubit.resolveCoverFor(FeedItem(
      id: album.id, type: 'album', name: album.name,
      artists: album.artistName, coverUrl: album.coverUrl,
    ));
    _resolvedAlbumCover = albumCover ?? album.coverUrl ?? widget.coverUrl;

    // Visible tracks as FeedItems (reused for queue seeding + neighbor preload).
    final albumFeedItems = album.tracks
        .where((t) => _isOnline || t.isDownloaded)
        .map((t) {
          final trackCoverUrl = t.coverUrl;
          final effectiveCoverUrl = (trackCoverUrl?.isNotEmpty == true)
              ? trackCoverUrl!
              : ((album.coverUrl?.isNotEmpty == true) ? album.coverUrl! : null);
          return FeedItem(id: t.trackId, type: 'track', name: t.name, artists: t.artistName,
              coverUrl: effectiveCoverUrl, albumName: album.name, durationMs: t.durationMs,
              isrc: t.isrc, source: src);
        })
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(album.name, overflow: TextOverflow.ellipsis),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: EdgeInsets.all(r.spacingM),
        children: [
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: r.titleSize * 2, height: r.titleSize * 2,
                child: albumCover != null && albumCover.isNotEmpty
                  ? imageFromUrl(albumCover, fit: BoxFit.cover, fallback: _placeholder(r, onBg))
                  : _placeholder(r, onBg),
              ),
            ),
            SizedBox(width: r.spacingM),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(album.name, style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w600, color: onBg)),
                SizedBox(height: 4),
                Text(album.artistName ?? '', style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.5))),
                Text('${album.totalTracks} ${loc.setup.miSpaceSongCount}  •  ${album.albumType ?? ''}',
                  style: TextStyle(fontSize: r.footerSize - 1, color: onBg.withValues(alpha: 0.35))),
              ],
            )),
          ]),
          SizedBox(height: r.spacingM),
          if (_isOnline)
            GestureDetector(
              onTap: _downloadAll,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingS),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: onBg.withValues(alpha: 0.1)),
                  color: onBg.withValues(alpha: 0.03),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  DownloadIndicator(
                    state: batchState.state,
                    size: 12,
                  ),
                  SizedBox(width: r.spacingS),
                  Expanded(
                    child: Text(
                      batchState.state == DownloadState.completed
                          ? '${loc.setup.downloaded} ✓'
                          : batchState.state == DownloadState.inProgress
                              ? '${(batchState.progress * 100).toInt()}%'
                              : loc.setup.downloaded,
                      style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.7)),
                    ),
                  ),
                  Icon(Icons.download, size: r.footerSize + 2, color: onBg.withValues(alpha: 0.4)),
                ]),
              ),
            ),
          if (!_isOnline)
            Container(
              margin: EdgeInsets.only(bottom: r.spacingS),
              padding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: 6),
              decoration: BoxDecoration(
                color: onBg.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.cloud_off, size: r.footerSize - 2, color: onBg.withValues(alpha: 0.4)),
                SizedBox(width: 6),
                Text('${loc.setup.downloaded} ${loc.setup.miSpaceSongs.toLowerCase()}',
                  style: TextStyle(fontSize: r.footerSize - 1, color: onBg.withValues(alpha: 0.4))),
              ]),
            ),
          ...albumFeedItems.map((feedItem) {
            final dID = 'track_${normalizeTrackId(feedItem.id)}_$src';
            final trackCoverUrl = feedItem.coverUrl;
            final displayCover = (trackCoverUrl?.isNotEmpty == true)
                ? likedCubit.resolveCoverFor(feedItem)
                : albumCover;
            final isLiked = likedCubit.isLiked(feedItem);
            void play() => context.read<QueueCubit>().playWithContext(albumFeedItems, feedItem);
            return Padding(
              padding: EdgeInsets.only(bottom: r.spacingXS),
              child: TrackCard(
                title: feedItem.name, subtitle: (feedItem.artists?.isNotEmpty == true) ? feedItem.artists! : ((album.artistName?.isNotEmpty == true) ? album.artistName! : ''),
                coverUrl: displayCover, isLiked: isLiked, readyKey: normalizeTrackId(feedItem.id),
                onLike: () => likedCubit.toggleLike(feedItem),
                downloadState: dlCubit.downloadStateFor(dID).state,
                onDownload: () => showDownloadOptions(context, feedItem, isDark),
                onDelete: () => dlCubit.deleteTrackDownload(feedItem.id, src),
                onTap: play,
                onShare: () => SharePlus.instance.share(ShareParams(
                  text: feedItem.albumName != null
                      ? '🎵 ${feedItem.name} — ${feedItem.artists ?? ''}\n💿 ${feedItem.albumName}'
                      : '🎵 ${feedItem.name} — ${feedItem.artists ?? ''}',
                )),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _placeholder(Responsive r, Color onBg) => Container(
    color: onBg.withValues(alpha: 0.06),
    child: Icon(Icons.album, color: onBg.withValues(alpha: 0.2), size: r.titleSize),
  );
}


