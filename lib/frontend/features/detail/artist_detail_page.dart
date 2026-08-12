import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import '../../../backend/cache/detail_cache.dart';
import '../../../backend/cache/detail_memory_cache.dart';
import '../../../backend/cache/playback_cache.dart';
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
import '../../shared/widgets/download_options_sheet.dart';
import '../../../backend/services/connectivity_service.dart';
import '../../../injection.dart';
import 'album_detail_page.dart';

class ArtistDetailPage extends StatefulWidget {
  final String artistId;
  final String artistName;
  final String source;
  const ArtistDetailPage({super.key, required this.artistId, this.artistName = '', this.source = ''});

  @override
  State<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends State<ArtistDetailPage> {
  ArtistDetail? _artist;
  bool _loading = true;
  bool _error = false;
  bool _isOnline = true;

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

    ArtistDetail? detail;

    // Session memory cache (fastest — avoids any I/O within same session)
    detail = memCache.getArtist(widget.artistId);
    if (detail != null && (detail.topTracks.isNotEmpty || detail.topAlbums.isNotEmpty)) {
      if (mounted) setState(() { _artist = detail; _loading = false; });
      return;
    }

    // Try local Drift DB first (survives restarts, populated by syncArtistDetail)
    detail = await pb.getArtistDetailLocal(widget.artistId);
    if (detail != null && (detail.topTracks.isNotEmpty || detail.topAlbums.isNotEmpty)) {
      if (mounted) setState(() { _artist = detail; _loading = false; });
      memCache.setArtist(widget.artistId, detail);
      if (_isOnline) _refreshFromApi(cache, backend, pb);
      return;
    }

    // No local data: try DetailCache (JSON TTL cache) then API
    try {
      detail = await loadDetailWithFallback(
        id: widget.artistId,
        source: widget.source,
        getLocal: (id) => cache.getArtistDetail(id),
        fetchRemote: (id, src) => backend.fetchArtistDetail(id, src),
        fromJson: ArtistDetail.fromJson,
      );
      if (detail != null) memCache.setArtist(widget.artistId, detail);
    } catch (_) {}

    if (mounted) setState(() { _artist = detail; _loading = false; _error = detail == null; });
  }

  Future<void> _refreshFromApi(DetailCache cache, BackendService backend, PlaybackCache pb) async {
    try {
      final json = await backend.fetchArtistDetail(widget.artistId, widget.source);
      if (json.isNotEmpty && json != '{}') {
        final fresh = ArtistDetail.fromJson(jsonDecode(json) as Map<String, dynamic>);
        sl<DetailMemoryCache>().setArtist(widget.artistId, fresh);
        await pb.syncArtistDetail(fresh, source: widget.source);
        await cache.setArtistDetail(widget.artistId, json);
        if (mounted) setState(() { _artist = fresh; _error = false; });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? Colors.white : Colors.black;
    final loc = AppLocalizations.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.artistName.isNotEmpty ? widget.artistName : loc.setup.miSpaceArtist)),
        body: Center(child: CircularProgressIndicator(strokeWidth: 2, color: onBg.withValues(alpha: 0.3))),
      );
    }
    if (_artist == null) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.setup.miSpaceArtist)),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(loc.setup.feedEmpty, style: TextStyle(color: onBg.withValues(alpha: 0.4))),
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

    final artist = _artist!;
    final likedCubit = context.watch<LikeCubit>();
    final dlCubit = context.watch<DownloadCubit>();
    // Prefer locally cached image (imagePath) over network imageUrl.
    final artistImage = (artist.imagePath?.isNotEmpty == true)
        ? artist.imagePath
        : (artist.imageUrl?.isNotEmpty == true ? artist.imageUrl : null);

    // Visible top tracks as FeedItems (reused for queue seeding + neighbor preload).
    final artistTracks = artist.topTracks.map((t) {
      final src = widget.source.isNotEmpty ? widget.source : (t.provider ?? '');
      return FeedItem(id: t.trackId, type: 'track', name: t.name,
        coverUrl: t.coverUrl, artists: artist.name, source: src,
        albumName: t.albumName, durationMs: t.durationMs, isrc: t.isrc);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(artist.name, overflow: TextOverflow.ellipsis),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: EdgeInsets.all(r.spacingM),
        children: [
          Row(children: [
            ClipOval(
              child: SizedBox(
                width: r.titleSize * 2, height: r.titleSize * 2,
                child: artistImage != null && artistImage.isNotEmpty
                  ? imageFromUrl(artistImage, fit: BoxFit.cover, fallback: _artistPlaceholder(r, onBg))
                  : _artistPlaceholder(r, onBg),
              ),
            ),
            SizedBox(width: r.spacingM),
            Expanded(child: Text(artist.name,
              style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w600, color: onBg))),
          ]),
          if (_isOnline && artist.topTracks.isNotEmpty) ...[
            SizedBox(height: r.spacingM),
            Row(children: [
              Text(loc.setup.searchTracks, style: TextStyle(fontSize: r.footerSize + 1, fontWeight: FontWeight.w600, color: onBg)),
            ]),
            SizedBox(height: r.spacingS),
            ...artistTracks.map((feedItem) {
              final src = feedItem.source ?? '';
              final dID = 'track_${normalizeTrackId(feedItem.id)}_$src';
              void play() => context.read<QueueCubit>().playWithContext(artistTracks, feedItem);
              return Padding(
                padding: EdgeInsets.only(bottom: r.spacingXS),
                child: TrackCard(
                  title: feedItem.name, subtitle: artist.name,
                  coverUrl: likedCubit.resolveCoverFor(feedItem),
                  readyKey: normalizeTrackId(feedItem.id),
                  isLiked: likedCubit.isLiked(feedItem),
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
          if (_isOnline && artist.topAlbums.isNotEmpty) ...[
            SizedBox(height: r.spacingM),
            Text(loc.setup.searchAlbums, style: TextStyle(fontSize: r.footerSize + 1, fontWeight: FontWeight.w600, color: onBg)),
            SizedBox(height: r.spacingS),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: artist.topAlbums.length,
                separatorBuilder: (_, _) => SizedBox(width: r.spacingXS),
                itemBuilder: (_, i) {
                  final a = artist.topAlbums[i];
                  final albumItem = FeedItem(
                    id: a.albumId, type: 'album', name: a.name,
                    coverUrl: a.coverUrl, source: widget.source,
                  );
                  final albumCover = likedCubit.resolveCoverFor(albumItem);
                  final isAlbumLiked = likedCubit.isLiked(albumItem);
                  return SizedBox(
                    width: 140,
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: context.read<LikeCubit>(),
                          child: BlocProvider.value(
                            value: context.read<DownloadCubit>(),
                            child: BlocProvider.value(
                              value: context.read<QueueCubit>(),
                              child: AlbumDetailPage(albumId: a.albumId, source: widget.source, coverUrl: a.coverUrl)),
                          )))),
                      child: Column(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 140, height: 140,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                albumCover != null && albumCover.isNotEmpty
                                  ? imageFromUrl(albumCover, fit: BoxFit.cover,
                                      fallback: _placeholder(r, onBg))
                                  : _placeholder(r, onBg),
                                Positioned(
                                  top: 4, right: 4,
                                  child: GestureDetector(
                                    onTap: () => likedCubit.toggleLike(albumItem),
                                    child: Icon(
                                      isAlbumLiked ? Icons.favorite : Icons.favorite_border,
                                      color: isAlbumLiked ? Colors.red : Colors.white70,
                                      size: 20,
                                      shadows: const [Shadow(blurRadius: 4)],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(a.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: r.footerSize - 1, color: onBg)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ],
          if (!_isOnline) ...[
            SizedBox(height: r.spacingM),
            Row(children: [
              Icon(Icons.cloud_off, size: r.footerSize, color: onBg.withValues(alpha: 0.4)),
              SizedBox(width: 6),
              Text('${loc.setup.downloaded} ${loc.setup.miSpaceSongs.toLowerCase()}',
                style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.4))),
            ]),
            SizedBox(height: r.spacingS),
            ..._offlineTracks(likedCubit, dlCubit, r, onBg, isDark),
          ],
        ],
      ),
    );
  }

  List<Widget> _offlineTracks(LikeCubit likedCubit, DownloadCubit dlCubit, Responsive r, Color onBg, bool isDark) {
    final tracks = likedCubit.tracks.where((t) {
      final matches = t.artists?.toLowerCase().contains(widget.artistName.toLowerCase()) ?? false;
      return matches;
    }).toList();

    if (tracks.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(vertical: r.spacingL),
          child: Center(
            child: Text('No hay canciones guardadas de este artista',
              style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.4))),
          ),
        ),
      ];
    }

    final feedItems = tracks.map((t) => FeedItem(
      id: t.id, type: 'track', name: t.name,
      artists: t.artists, coverUrl: t.coverUrl,
      albumName: t.albumName, durationMs: t.durationMs,
      source: t.source ?? widget.source,
    )).toList();
    return feedItems.asMap().entries.map((entry) {
      final feedItem = entry.value;
      final t = tracks[entry.key];
      final dID = 'track_${normalizeTrackId(t.id)}_${t.source ?? widget.source}';
      void play() => context.read<QueueCubit>().playWithContext(feedItems, feedItem);
      return Padding(
        padding: EdgeInsets.only(bottom: r.spacingXS),
        child: TrackCard(
          title: t.name, subtitle: t.artists ?? widget.artistName,
          coverUrl: likedCubit.resolveCoverFor(feedItem),
          readyKey: normalizeTrackId(t.id),
          isLiked: true,
          onLike: () => likedCubit.toggleLike(feedItem),
          downloadState: dlCubit.downloadStateFor(dID).state,
          onDownload: () => showDownloadOptions(context, feedItem, isDark),
          onDelete: () => dlCubit.deleteTrackDownload(t.id, t.source ?? widget.source),
          onTap: play,
          onShare: () => SharePlus.instance.share(ShareParams(
            text: feedItem.albumName != null
                ? '🎵 ${feedItem.name} — ${feedItem.artists ?? ''}\n💿 ${feedItem.albumName}'
                : '🎵 ${feedItem.name} — ${feedItem.artists ?? ''}',
          )),
        ),
      );
    }).toList();
  }

  Widget _placeholder(Responsive r, Color onBg) => Container(
    color: onBg.withValues(alpha: 0.06),
    child: Icon(Icons.album, color: onBg.withValues(alpha: 0.2), size: r.titleSize * 0.5),
  );

  Widget _artistPlaceholder(Responsive r, Color onBg) => Container(
    color: onBg.withValues(alpha: 0.06),
    child: Icon(Icons.person, color: onBg.withValues(alpha: 0.2), size: r.titleSize),
  );
}


