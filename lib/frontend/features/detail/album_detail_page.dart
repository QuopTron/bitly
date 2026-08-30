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
import '../../shared/widgets/detail_header.dart';
import '../../shared/widgets/download_options_sheet.dart';
import '../../shared/theme/app_colors.dart';
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
    // Offline filter: show track if online OR if it's downloaded (check both
    // DetailTrack.isDownloaded and DownloadCubit state for freshness).
    final albumFeedItems = album.tracks
        .where((t) {
          if (_isOnline) return true;
          if (t.isDownloaded) return true;
          // Check DownloadCubit for up-to-date download status
          final dID = 'track_${normalizeTrackId(t.trackId)}_$src';
          return dlCubit.downloadStateFor(dID).state == DownloadState.completed;
        })
        .map((t) {
          final trackCoverUrl = t.coverUrl;
          final effectiveCoverUrl = (trackCoverUrl?.isNotEmpty == true)
              ? trackCoverUrl!
              : ((album.coverUrl?.isNotEmpty == true) ? album.coverUrl! : null);
          return FeedItem(id: t.trackId, type: 'track', name: t.name, artists: t.artistName,
              coverUrl: effectiveCoverUrl, albumName: album.name, durationMs: t.durationMs,
              isrc: t.isrc, source: src, spotifyId: t.spotifyId,
              deezerId: t.deezerId, tidalId: t.tidalId, qobuzId: t.qobuzId);
        })
        .toList();

    final isLikedAlbum = likedCubit.isLiked(FeedItem(
      id: album.id, type: 'album', name: album.name,
    ));

    return DetailHeader(
      coverUrl: _resolvedAlbumCover,
      title: album.name,
      subtitle: album.artistName ?? '',
      heroTag: 'album_${album.id}',
      badge: '${album.totalTracks} ${loc.setup.miSpaceSongCount}  •  ${album.albumType ?? ''}',
      actions: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CircleActionButton(
            icon: isLikedAlbum ? Icons.favorite : Icons.favorite_border,
            color: isLikedAlbum ? Colors.red : null,
            onTap: () => likedCubit.toggleLike(FeedItem(
              id: album.id, type: 'album', name: album.name,
              artists: album.artistName, coverUrl: _resolvedAlbumCover,
            )),
          ),
          SizedBox(width: r.spacingS),
          _CircleActionButton(
            icon: batchState.state == DownloadState.completed
                ? Icons.check_circle
                : batchState.state == DownloadState.inProgress
                    ? Icons.hourglass_top_rounded
                    : Icons.download,
            color: batchState.state == DownloadState.completed
                ? AppColors.greenBright
                : batchState.state == DownloadState.inProgress
                    ? const Color(0xFFFF9800)
                    : null,
            onTap: _isOnline ? _downloadAll : null,
          ),
          SizedBox(width: r.spacingS),
          _CircleActionButton(
            icon: Icons.play_arrow_rounded,
            filled: true,
            onTap: albumFeedItems.isNotEmpty
                ? () => sl<QueueCubit>().playWithContext(albumFeedItems, albumFeedItems.first)
                : null,
          ),
        ],
      ),
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: r.spacingS),
        children: [
          if (!_isOnline)
            Container(
              margin: EdgeInsets.only(bottom: r.spacingS),
              padding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.cloud_off, size: r.footerSize - 2,
                  color: Colors.white.withValues(alpha: 0.4)),
                SizedBox(width: 6),
                Text('${loc.setup.downloaded} ${loc.setup.miSpaceSongs.toLowerCase()}',
                  style: TextStyle(fontSize: r.footerSize - 1,
                    color: Colors.white.withValues(alpha: 0.4))),
              ]),
            ),
          ...albumFeedItems.map((feedItem) {
            final dID = 'track_${normalizeTrackId(feedItem.id)}_$src';
            final trackCoverUrl = feedItem.coverUrl;
            final displayCover = (trackCoverUrl?.isNotEmpty == true)
                ? likedCubit.resolveCoverFor(feedItem)
                : albumCover;
            final isLiked = likedCubit.isLiked(feedItem);
            void play() => sl<QueueCubit>().playWithContext(albumFeedItems, feedItem);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: r.spacingXS * 0.5),
              child: TrackCard(
                title: feedItem.name,
                subtitle: (feedItem.artists?.isNotEmpty == true)
                    ? feedItem.artists!
                    : ((album.artistName?.isNotEmpty == true) ? album.artistName! : ''),
                coverUrl: displayCover, isLiked: isLiked,
                readyKey: normalizeTrackId(feedItem.id),
                textScale: 1.2,
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
          SizedBox(height: r.spacingL + 90),
        ],
      ),
    );
  }
}

/// Compact circular action button used in the detail header actions row.
class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final bool filled;

  const _CircleActionButton({
    required this.icon,
    this.onTap,
    this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = filled
        ? AppColors.greenBright
        : (color ?? (isDark ? Colors.white : Colors.black)).withValues(alpha: 0.12);
    final fgColor = filled
        ? Colors.black
        : color ?? (isDark ? Colors.white : Colors.black);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onTap != null ? bgColor : bgColor.withValues(alpha: 0.4),
          boxShadow: filled ? [
            BoxShadow(
              color: AppColors.greenBright.withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ] : null,
        ),
        child: Icon(icon, size: 24, color: fgColor),
      ),
    );
  }
}
