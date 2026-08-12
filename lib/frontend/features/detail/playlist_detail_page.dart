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
import '../../shared/widgets/download_indicator.dart';
import '../../shared/widgets/download_options_sheet.dart';
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

    PlaylistDetail? detail;

    // Session memory cache (fastest — avoids any I/O within same session)
    detail = memCache.getPlaylist(widget.collectionId);
    if (detail != null && detail.tracks.isNotEmpty) {
      if (mounted) setState(() { _detail = detail; _loading = false; });
      return;
    }

    // Try local Drift DB first (survives restarts, populated by syncPlaylistDetail)
    detail = await pb.getPlaylistDetailLocal(widget.collectionId);
    if (detail != null && detail.tracks.isNotEmpty) {
      if (mounted) setState(() { _detail = detail; _loading = false; });
      memCache.setPlaylist(widget.collectionId, detail);
      if (_isOnline) {
        _refreshFromApi(cache, backend, pb);
      }
      return;
    }

    // No local data (or stale with empty tracks): try DetailCache (JSON TTL cache) then API
    try {
      detail = await loadDetailWithFallback(
        id: widget.collectionId,
        source: widget.source,
        getLocal: (id) => cache.getPlaylistDetail(id),
        fetchRemote: (id, src) => backend.fetchPlaylistDetail(id, src),
        fromJson: PlaylistDetail.fromJson,
      );
      if (detail == null) {
        final local = await pb.getPlaylistDetailLocal(widget.collectionId);
        if (local != null && local.tracks.isNotEmpty) {
          detail = local;
        }
      }
      if (detail != null) {
        memCache.setPlaylist(widget.collectionId, detail);
      }
    } catch (_) {}

    // Last resort: build from batch download data
    detail ??= await _buildFromBatch();

    if (mounted) setState(() { _detail = detail; _loading = false; _error = detail == null; });
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
  /// Build a [PlaylistDetail] from batch download data when API/local cache unavailable.
  Future<PlaylistDetail?> _buildFromBatch() async {
    final dlCache = sl<DownloadCache>();
    var batch = await dlCache.getBatchByItem('playlist', widget.collectionId, widget.source);
    if (batch == null && widget.source.isNotEmpty) {
      batch = await dlCache.getBatchByItem('playlist', widget.collectionId, '');
    }
    if (batch == null || batch.trackIds == null || batch.trackIds!.isEmpty) return null;

    final List<dynamic> rawIds;
    try {
      rawIds = jsonDecode(batch.trackIds!) as List<dynamic>;
    } catch (_) {
      return null;
    }

    final history = jsonDecode(await dlCache.getDownloadHistory()) as List<dynamic>;
    final trackMap = <String, Map<String, dynamic>>{};
    for (final entry in history) {
      final m = entry as Map<String, dynamic>;
      final id = (m['id'] as String?)?.toLowerCase() ?? '';
      trackMap[id] = m;
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
        albumName: meta?['album_name'] as String? ?? '',
        provider: meta?['providerSource'] as String? ?? widget.source,
      ));
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

    final tracks = detail.tracks.map((t) => <String, dynamic>{
      'track_id': t.trackId,
      'track_title': t.name,
      'artist_name': t.artistName ?? '',
      'album_name': t.albumName ?? '',
      'source': src,
      'isrc': t.isrc,
      'duration_ms': t.durationMs,
      'cover_url': (t.coverUrl?.isNotEmpty == true) ? t.coverUrl! : (detail.coverPath ?? widget.coverUrl),
    }).toList();

    // Show quality selector before starting batch
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
    final onBg = isDark ? Colors.white : Colors.black;
    final loc = AppLocalizations.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.playlistName.isNotEmpty ? widget.playlistName : loc.setup.miSpacePlaylists)),
        body: Center(child: CircularProgressIndicator(strokeWidth: 2, color: onBg.withValues(alpha: 0.3))),
      );
    }
    if (_detail == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.playlistName.isNotEmpty ? widget.playlistName : loc.setup.miSpacePlaylists)),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error ? loc.setup.miSpaceEmptyPlaylists : loc.setup.miSpaceEmptyPlaylists,
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

    final detail = _detail!;
    final likedCubit = context.watch<LikeCubit>();
    final dlCubit = context.watch<DownloadCubit>();
    final src = widget.source.isNotEmpty ? widget.source : (detail.tracks.isNotEmpty ? (detail.tracks.first.provider ?? '') : '');
    final batchKey = 'playlist_${normalizeTrackId(detail.id)}_$src';
    final batchState = dlCubit.downloadStateFor(batchKey);

    final hasLocalFiles =
        detail.tracks.any((t) => t.filePath != null && t.filePath!.isNotEmpty);

    // Visible tracks as FeedItems (reused for queue seeding + neighbor preload).
    final playlistFeedItems = detail.tracks
        .where((t) => _isOnline || t.isDownloaded)
        .map((t) {
          final effectiveCoverUrl = (t.coverUrl?.isNotEmpty == true)
              ? t.coverUrl!
              : ((detail.coverPath?.isNotEmpty == true) ? detail.coverPath! : widget.coverUrl);
          return FeedItem(id: t.trackId, type: 'track', name: t.name,
              artists: t.artistName, coverUrl: effectiveCoverUrl,
              albumName: t.albumName, durationMs: t.durationMs, isrc: t.isrc,
              source: src);
        })
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.name, overflow: TextOverflow.ellipsis),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          if (hasLocalFiles)
            IconButton(
              icon: Icon(Icons.file_download_outlined, color: onBg.withValues(alpha: 0.7)),
              tooltip: 'Exportar playlist',
              onPressed: () => _exportPlaylist(detail, isDark),
            ),
        ],
      ),
      body: detail.tracks.isEmpty
        ? Center(child: Text(loc.setup.miSpaceEmptyPlaylists, style: TextStyle(color: onBg.withValues(alpha: 0.4))))
        : ListView(
            padding: EdgeInsets.all(r.spacingM),
            children: [
              Row(children: [
                Text('${detail.itemCount} ${loc.setup.miSpaceSongCount}',
                  style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.4))),
                const Spacer(),
                if (_isOnline)
                  GestureDetector(
                    onTap: _downloadAll,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingXS),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: onBg.withValues(alpha: 0.1)),
                        color: onBg.withValues(alpha: 0.03),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        DownloadIndicator(
                          state: batchState.state,
                          size: 12,
                        ),
                        SizedBox(width: r.spacingXS),
                        Text(
                          batchState.state == DownloadState.completed
                              ? '✓'
                              : batchState.state == DownloadState.inProgress
                                  ? '${(batchState.progress * 100).toInt()}%'
                                  : loc.setup.downloaded,
                          style: TextStyle(fontSize: r.footerSize - 1, color: onBg.withValues(alpha: 0.7)),
                        ),
                      ]),
                    ),
                  ),
              ]),
              SizedBox(height: r.spacingM),
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
              ...playlistFeedItems.map((feedItem) {
                final dID = 'track_${normalizeTrackId(feedItem.id)}_$src';
                final trackCover = likedCubit.resolveCoverFor(feedItem);
                final isLiked = likedCubit.isLiked(feedItem);
                void play() => context.read<QueueCubit>().playWithContext(playlistFeedItems, feedItem);
                return Padding(
                  padding: EdgeInsets.only(bottom: r.spacingXS),
                  child: TrackCard(
                    title: feedItem.name,
                    subtitle: feedItem.artists ?? '',
                    coverUrl: trackCover,
                    readyKey: normalizeTrackId(feedItem.id),
                    isLiked: isLiked,
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


