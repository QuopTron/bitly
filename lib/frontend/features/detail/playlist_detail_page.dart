import 'dart:async';
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
import '../../shared/utils/responsive.dart';
import '../../shared/utils/download_strategy.dart';
import '../../shared/detail/load_utils.dart';
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
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import '../../../backend/services/playlist_export_service.dart';
import '../../../injection.dart';

class PlaylistDetailPage extends StatefulWidget {
  final String collectionId;
  final String playlistName;
  final String source;
  final String? coverUrl;
  const PlaylistDetailPage({super.key, required this.collectionId, this.playlistName = '', this.source = '', this.coverUrl});

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  PlaylistDetail? _detail;
  bool _loading = true;
  bool _error = false;
  bool _isOnline = true;
  String? _resolvedCover;

  Future<void> _exportPlaylist(PlaylistDetail detail, bool isDark) async {
    final result = await PlaylistExportService.exportPlaylist(
      name: detail.name,
      tracks: detail.tracks,
      initialDirectory: await sl<SettingsCache>().getDownloadPath(),
    );

    if (!mounted) return;

    final outputDir = result.files.isNotEmpty
        ? p.dirname(result.files.first)
        : null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          PlaylistExportService.formatExportSummary(result),
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        backgroundColor: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFE8E8F0),
        duration: const Duration(seconds: 4),
        action: result.success && outputDir != null
            ? SnackBarAction(
                label: 'Abrir carpeta',
                textColor: isDark ? Colors.white70 : Colors.black87,
                onPressed: () => OpenFilex.open(outputDir),
              )
            : null,
      ),
    );
  }

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
    final dlCubit = sl<DownloadCubit>();

    PlaylistDetail? detail;
    bool allTracksDownloaded = false;

    // 1. Session memory cache (instant)
    detail = memCache.getPlaylist(widget.collectionId);
    if (detail != null && detail.tracks.isNotEmpty) {
      allTracksDownloaded = _areAllTracksDownloaded(detail, dlCubit);
      if (mounted) setState(() { _detail = detail; _loading = false; });
      if (!allTracksDownloaded && _isOnline) {
        _refreshFromApi(cache, backend, pb);
      }
      return;
    }

    // 2. Local Drift DB
    detail = await pb.getPlaylistDetailLocal(widget.collectionId);
    if (detail != null && detail.tracks.isNotEmpty) {
      allTracksDownloaded = _areAllTracksDownloaded(detail, dlCubit);
      memCache.setPlaylist(widget.collectionId, detail);
      if (mounted) setState(() { _detail = detail; _loading = false; });
      if (!allTracksDownloaded && _isOnline) {
        _refreshFromApi(cache, backend, pb);
      }
      return;
    }

    // 3. Batch download data (local, no network)
    detail = await _buildFromBatch();
    if (detail != null && detail.tracks.isNotEmpty) {
      allTracksDownloaded = _areAllTracksDownloaded(detail, dlCubit);
      memCache.setPlaylist(widget.collectionId, detail);
      unawaited(pb.syncPlaylistDetail(detail, source: widget.source));
      if (mounted) setState(() { _detail = detail; _loading = false; });
      if (!allTracksDownloaded && _isOnline) {
        _refreshFromApi(cache, backend, pb);
      }
      return;
    }

    // 4. No local data: try DetailCache then API
    try {
      detail = await loadDetailWithFallback(
        id: widget.collectionId,
        source: widget.source,
        getLocal: (id) => cache.getPlaylistDetail(id),
        fetchRemote: (id, src) => backend.fetchPlaylistDetail(id, src),
        fromJson: PlaylistDetail.fromJson,
      );
      if (detail != null) memCache.setPlaylist(widget.collectionId, detail);
    } catch (_) {}

    if (mounted) setState(() { _detail = detail; _loading = false; _error = detail == null; });
  }

  bool _areAllTracksDownloaded(PlaylistDetail detail, DownloadCubit dlCubit) {
    if (detail.tracks.isEmpty) return false;
    final src = widget.source.isNotEmpty ? widget.source : (detail.tracks.first.provider ?? '');
    for (final t in detail.tracks) {
      final dID = 'track_${normalizeTrackId(t.trackId)}_$src';
      if (dlCubit.downloadStateFor(dID).state != DownloadState.completed) return false;
    }
    return true;
  }

  Future<void> _refreshFromApi(DetailCache cache, BackendService backend, PlaybackCache pb) async {
    try {
      final json = await backend.fetchPlaylistDetail(widget.collectionId, widget.source);
      if (json.isNotEmpty && json != '{}') {
        final fresh = PlaylistDetail.fromJson(jsonDecode(json) as Map<String, dynamic>);
        sl<DetailMemoryCache>().setPlaylist(widget.collectionId, fresh);
        await pb.syncPlaylistDetail(fresh, source: widget.source);
        await cache.setPlaylistDetail(widget.collectionId, json);
        if (mounted) setState(() { _detail = fresh; _error = false; });
      }
    } catch (_) {}
  }

  Future<PlaylistDetail?> _buildFromBatch() async {
    final dlCache = sl<DownloadCache>();
    var batch = await dlCache.getBatchByItem('playlist', widget.collectionId, widget.source);
    if (batch == null && widget.source.isNotEmpty) {
      batch = await dlCache.getBatchByItem('playlist', widget.collectionId, '');
    }
    if (batch == null || batch.trackIds == null || batch.trackIds!.isEmpty) return null;

    final List<dynamic> rawIds;
    try { rawIds = jsonDecode(batch.trackIds!) as List<dynamic>; } catch (_) { return null; }

    // Determine format: new batches store objects {id, name, artist, cover},
    // old batches store plain state-key strings.
    final bool enriched = rawIds.isNotEmpty && rawIds.first is Map<String, dynamic>;

    // For old-format batches, fall back to download history for metadata.
    Map<String, Map<String, dynamic>>? historyMap;
    if (!enriched) {
      final history = jsonDecode(await dlCache.getDownloadHistory()) as List<dynamic>;
      historyMap = <String, Map<String, dynamic>>{};
      for (final entry in history) {
        final m = entry as Map<String, dynamic>;
        final id = (m['id'] as String?)?.toLowerCase() ?? '';
        historyMap[id] = m;
      }
    }

    final tracks = <DetailTrack>[];
    for (final raw in rawIds) {
      if (enriched) {
        final obj = raw as Map<String, dynamic>;
        final stateKey = (obj['id'] ?? '') as String;
        final parts = stateKey.split('_');
        final normalizedId = parts.length >= 3
            ? parts.sublist(1, parts.length - 1).join('_')
            : stateKey;
        final name = (obj['name'] ?? '') as String;
        tracks.add(DetailTrack(
          trackId: normalizedId,
          name: name.isNotEmpty ? name : normalizedId,
          artistName: (obj['artist'] ?? '') as String,
          coverUrl: (obj['cover'] ?? '') as String,
          provider: widget.source,
        ));
      } else {
        final stateKey = raw as String;
        final parts = stateKey.split('_');
        if (parts.length < 3) continue;
        final normalizedId = parts.sublist(1, parts.length - 1).join('_');
        final meta = historyMap?[normalizedId] ?? historyMap?[stateKey.toLowerCase()];
        tracks.add(DetailTrack(
          trackId: meta?['id'] as String? ?? normalizedId,
          name: (meta?['track_name'] as String?)?.isNotEmpty == true
              ? meta!['track_name'] as String : normalizedId,
          durationMs: (meta?['duration'] as num?)?.toInt() ?? 0,
          isrc: meta?['isrc'] as String? ?? '',
          coverUrl: meta?['cover_url'] as String? ?? '',
          coverPath: meta?['cover_path'] as String? ?? '',
          artistName: meta?['artist_name'] as String? ?? '',
          albumName: meta?['album_name'] as String? ?? '',
          provider: meta?['providerSource'] as String? ?? widget.source,
        ));
      }
    }

    if (tracks.isEmpty) return null;
    return PlaylistDetail(
      id: batch.itemId ?? widget.collectionId,
      name: batch.name ?? widget.playlistName,
      itemCount: tracks.length,
      tracks: tracks,
    );
  }

  Future<void> _downloadAll() async {
    if (_detail == null || _detail!.tracks.isEmpty) return;
    final dlCubit = context.read<DownloadCubit>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = await sl<SettingsCache>().getDownloadSettings();
    final src = widget.source.isNotEmpty ? widget.source : (_detail!.tracks.first.provider ?? '');
    final detail = _detail!;

    // Only download tracks that are NOT already completed
    final tracks = detail.tracks.where((t) {
      final dID = 'track_${normalizeTrackId(t.trackId)}_$src';
      return dlCubit.downloadStateFor(dID).state != DownloadState.completed;
    }).map((t) => <String, dynamic>{
      'track_id': t.trackId,
      'track_title': t.name,
      'artist_name': t.artistName ?? '',
      'album_name': t.albumName ?? '',
      'source': src,
      'isrc': t.isrc,
      'duration_ms': t.durationMs,
      'cover_url': (t.coverUrl?.isNotEmpty == true) ? t.coverUrl! : (detail.coverPath ?? widget.coverUrl),
    }).toList();

    if (tracks.isEmpty) return;
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DownloadOptionsSheet(
        item: FeedItem(
          id: detail.id, type: 'playlist', name: detail.name,
          coverUrl: widget.coverUrl, source: src,
        ),
        isDark: isDark,
        dlSettings: settings,
        onQualitySelected: (quality) {
          dlCubit.startPlaylistDownload(detail.id, tracks,
            settings: settings, source: src, qualityOverride: quality);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
        body: Center(child: CircularProgressIndicator(strokeWidth: 2,
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3))),
      );
    }
    if (_detail == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error ? loc.setup.miSpaceEmptyPlaylists : loc.setup.miSpaceEmptyPlaylists,
              style: TextStyle(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4))),
            if (_error)
              TextButton.icon(
                onPressed: _load,
                icon: Icon(Icons.refresh, size: 18,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6)),
                label: Text(loc.setup.retry,
                  style: TextStyle(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6))),
              ),
          ]),
        ),
      );
    }

    final detail = _detail!;
    final likedCubit = context.watch<LikeCubit>();
    final dlCubit = context.watch<DownloadCubit>();
    var src = widget.source.isNotEmpty ? widget.source : (detail.tracks.isNotEmpty ? (detail.tracks.first.provider ?? '') : '');
    // If source is empty, try to find it from the download batch metadata
    if (src.isEmpty) {
      final batchSrc = dlCubit.findBatchSource('playlist', detail.id);
      if (batchSrc.isNotEmpty) src = batchSrc;
    }
    final batchKey = 'playlist_${normalizeTrackId(detail.id)}_$src';
    final batchState = dlCubit.downloadStateFor(batchKey);

    // Compute per-track download progress for the badge
    int downloadedCount = 0;
    for (final t in detail.tracks) {
      final dID = 'track_${normalizeTrackId(t.trackId)}_$src';
      if (dlCubit.downloadStateFor(dID).state == DownloadState.completed) {
        downloadedCount++;
      }
    }
    final totalCount = detail.tracks.length;
    final allDownloaded = downloadedCount >= totalCount && totalCount > 0;
    final hasDownloads = downloadedCount > 0;

    final hasLocalFiles = detail.tracks.any((t) => t.filePath != null && t.filePath!.isNotEmpty);

    // Resolve cover from likes or widget
    final likedPlaylist = likedCubit.state.allLiked[detail.id];
    final likedCover = likedPlaylist?.localCoverPath ?? likedPlaylist?.coverUrl;
    _resolvedCover = likedCover ?? widget.coverUrl;

    final playlistFeedItems = detail.tracks
        .where((t) {
          if (_isOnline) return true;
          final dID = 'track_${normalizeTrackId(t.trackId)}_$src';
          return dlCubit.downloadStateFor(dID).state == DownloadState.completed;
        })
        .map((t) {
          final effectiveCoverUrl = (t.coverUrl?.isNotEmpty == true)
              ? t.coverUrl!
              : ((detail.coverPath?.isNotEmpty == true) ? detail.coverPath! : widget.coverUrl);
          return FeedItem(id: t.trackId, type: 'track', name: t.name,
              artists: t.artistName, coverUrl: effectiveCoverUrl,
              albumName: t.albumName, durationMs: t.durationMs, isrc: t.isrc,
              source: src, spotifyId: t.spotifyId,
              deezerId: t.deezerId, tidalId: t.tidalId, qobuzId: t.qobuzId);
        })
        .toList();

    final isLikedPlaylist = likedCubit.isLiked(FeedItem(
      id: detail.id, type: 'playlist', name: detail.name,
      source: src,
    ));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
      body: DetailHeader(
        coverUrl: _resolvedCover,
        title: detail.name,
        subtitle: allDownloaded
            ? '${detail.itemCount} ${loc.setup.miSpaceSongCount}  •  ✓ ${loc.setup.downloaded}'
            : hasDownloads
                ? '${detail.itemCount} ${loc.setup.miSpaceSongCount}  •  $downloadedCount/$totalCount ${loc.setup.downloaded.toLowerCase()}'
                : '${detail.itemCount} ${loc.setup.miSpaceSongCount}',
        heroTag: 'playlist_${detail.id}',
        actions: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GlassActionButton(
              icon: isLikedPlaylist ? Icons.favorite : Icons.favorite_border,
              color: isLikedPlaylist ? Colors.red : null,
              onTap: () => likedCubit.toggleLike(FeedItem(
                id: detail.id, type: 'playlist', name: detail.name,
                source: src, coverUrl: _resolvedCover,
              )),
            ),
            SizedBox(width: r.spacingS),
            _GlassActionButton(
              icon: batchState.state == DownloadState.completed || allDownloaded
                  ? Icons.check_circle_outline
                  : batchState.state == DownloadState.inProgress
                      ? Icons.hourglass_top_rounded
                      : Icons.download_rounded,
              color: batchState.state == DownloadState.completed || allDownloaded
                  ? AppColors.greenBright
                  : batchState.state == DownloadState.inProgress
                      ? const Color(0xFFFF9800)
                      : null,
              onTap: _isOnline && !allDownloaded ? _downloadAll : null,
            ),
            SizedBox(width: r.spacingS),
            _GlassActionButton(
              icon: Icons.play_arrow_rounded,
              filled: true,
              onTap: playlistFeedItems.isNotEmpty
                  ? () => sl<QueueCubit>().playWithContext(playlistFeedItems, playlistFeedItems.first)
                  : null,
            ),
            if (hasLocalFiles) ...[
              SizedBox(width: r.spacingS),
              _GlassActionButton(
                icon: Icons.file_download_outlined,
                onTap: () => _exportPlaylist(detail, isDark),
              ),
            ],
          ],
        ),
        children: [
          if (!_isOnline)
            Container(
              margin: EdgeInsets.symmetric(horizontal: r.spacingS),
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
          ...playlistFeedItems.map((feedItem) {
            final dID = 'track_${normalizeTrackId(feedItem.id)}_$src';
            final trackCover = likedCubit.resolveCoverFor(feedItem);
            final isLiked = likedCubit.isLiked(feedItem);
            void play() => sl<QueueCubit>().playWithContext(playlistFeedItems, feedItem);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: r.spacingXS * 0.5),
              child: TrackCard(
                title: feedItem.name,
                subtitle: feedItem.artists ?? '',
                coverUrl: trackCover,
                readyKey: normalizeTrackId(feedItem.id),
                isLiked: isLiked,
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
        ],
      ),
    );
  }
}

/// Futuristic glassmorphism action button.
class _GlassActionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final bool filled;
  const _GlassActionButton({
    required this.icon,
    this.onTap,
    this.color,
    this.filled = false,
  });

  @override
  State<_GlassActionButton> createState() => _GlassActionButtonState();
}

class _GlassActionButtonState extends State<_GlassActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0,
      upperBound: 1,
    );
    _scaleAnim = Tween(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.color ?? (isDark ? AppColors.greenBright : AppColors.greenDeep);
    final enabled = widget.onTap != null;

    final bgAlpha = widget.filled ? 0.22 : 0.08;
    final bgColor = widget.filled
        ? accent.withValues(alpha: bgAlpha)
        : (isDark ? Colors.white : Colors.black).withValues(alpha: bgAlpha);

    final borderColor = widget.filled
        ? accent.withValues(alpha: 0.5)
        : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12);

    final fgColor = widget.filled
        ? accent
        : widget.color ?? (isDark ? Colors.white : Colors.black);

    return GestureDetector(
      onTapDown: enabled ? (_) => _scaleCtrl.forward() : null,
      onTapUp: enabled ? (_) => _scaleCtrl.reverse() : null,
      onTapCancel: enabled ? () => _scaleCtrl.reverse() : null,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnim.value,
            child: child,
          );
        },
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? bgColor : bgColor.withValues(alpha: 0.3),
            border: Border.all(
              color: enabled ? borderColor : borderColor.withValues(alpha: 0.3),
              width: 1.0,
            ),
            boxShadow: widget.filled
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Icon(widget.icon, size: 22, color: enabled ? fgColor : fgColor.withValues(alpha: 0.3)),
        ),
      ),
    );
  }
}
