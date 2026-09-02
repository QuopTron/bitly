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
import '../../shared/widgets/shimmer_skeleton.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/models/detail_models.dart';
import '../../shared/models/feed_models.dart';
import '../../../backend/services/like_cubit.dart';
import '../../../backend/services/download_cubit.dart';
import '../../../backend/services/queue_cubit.dart';
import '../../shared/widgets/track_card.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/detail_header.dart';
import '../../shared/widgets/download_options_sheet.dart';
import '../../../backend/services/connectivity_service.dart';
import '../../../injection.dart';
import 'album_detail_page.dart';

class ArtistDetailPage extends StatefulWidget {
  final String artistId;
  final String artistName;
  final String source;
  const ArtistDetailPage({
    super.key,
    required this.artistId,
    this.artistName = '',
    this.source = '',
  });

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

    detail = memCache.getArtist(widget.artistId);
    if (detail != null && (detail.topTracks.isNotEmpty || detail.topAlbums.isNotEmpty)) {
      if (mounted) setState(() { _artist = detail; _loading = false; });
      return;
    }

    detail = await pb.getArtistDetailLocal(widget.artistId);
    if (detail != null && (detail.topTracks.isNotEmpty || detail.topAlbums.isNotEmpty)) {
      if (mounted) setState(() { _artist = detail; _loading = false; });
      memCache.setArtist(widget.artistId, detail);
      if (_isOnline) _refreshFromApi(cache, backend, pb);
      return;
    }

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
    final loc = AppLocalizations.of(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
        body: const DetailSkeleton(),
      );
    }
    if (_artist == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(loc.setup.feedEmpty,
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

    final artist = _artist!;
    final likedCubit = context.watch<LikeCubit>();
    final dlCubit = context.watch<DownloadCubit>();
    final artistImage = (artist.imagePath?.isNotEmpty == true)
        ? artist.imagePath
        : (artist.imageUrl?.isNotEmpty == true ? artist.imageUrl : null);

    final artistTracks = artist.topTracks.map((t) {
      final src = widget.source.isNotEmpty ? widget.source : (t.provider ?? '');
      return FeedItem(
        id: t.trackId, type: 'track', name: t.name,
        coverUrl: t.coverUrl, artists: artist.name, source: src,
        albumName: t.albumName, durationMs: t.durationMs, isrc: t.isrc,
        spotifyId: t.spotifyId, deezerId: t.deezerId,
        tidalId: t.tidalId, qobuzId: t.qobuzId,
      );
    }).toList();

    final subtitle = [
      if (artist.topTracks.isNotEmpty) '${artist.topTracks.length} ${loc.setup.searchTracks}',
      if (artist.topAlbums.isNotEmpty) '${artist.topAlbums.length} ${loc.setup.searchAlbums}',
    ].join(' • ');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
      body: DetailHeader(
        coverUrl: artistImage,
        title: artist.name,
        subtitle: subtitle.isNotEmpty ? subtitle : '',
        heroTag: 'artist_${artist.id}',
        coverSize: 160,
        actions: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GlassActionBtn(
              icon: Icons.play_arrow_rounded,
              filled: true,
              onTap: artistTracks.isNotEmpty
                  ? () => sl<QueueCubit>().playWithContext(artistTracks, artistTracks.first)
                  : null,
            ),
          ],
        ),
        children: [
          // Top tracks
          if (_isOnline && artist.topTracks.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.spacingS),
              child: Text(
                loc.setup.searchTracks,
                style: TextStyle(
                  fontSize: r.footerSize + 1,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: r.spacingS),
            ...artistTracks.map((feedItem) {
              final src = feedItem.source ?? '';
              final dID = 'track_${normalizeTrackId(feedItem.id)}_$src';
              void play() => sl<QueueCubit>().playWithContext(artistTracks, feedItem);
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: r.spacingXS * 0.5),
                child: TrackCard(
                  title: feedItem.name,
                  subtitle: artist.name,
                  coverUrl: likedCubit.resolveCoverFor(feedItem),
                  readyKey: normalizeTrackId(feedItem.id),
                  isLiked: likedCubit.isLiked(feedItem),
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

          // Top albums horizontal grid
          if (_isOnline && artist.topAlbums.isNotEmpty) ...[
            SizedBox(height: r.spacingM),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.spacingS),
              child: Text(
                loc.setup.searchAlbums,
                style: TextStyle(
                  fontSize: r.footerSize + 1,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: r.spacingS),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: r.spacingS),
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
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MultiBlocProvider(
                          providers: [
                            BlocProvider.value(value: context.read<LikeCubit>()),
                            BlocProvider.value(value: context.read<DownloadCubit>()),
                            BlocProvider.value(value: sl<QueueCubit>()),
                          ],
                          child: AlbumDetailPage(
                            albumId: a.albumId,
                            source: widget.source,
                            coverUrl: a.coverUrl,
                          ),
                        ),
                      ),
                    ),
                    child: SizedBox(
                      width: 140,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 140,
                              height: 140,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  albumCover != null && albumCover.isNotEmpty
                                      ? imageFromUrl(
                                          albumCover,
                                          fit: BoxFit.cover,
                                          fallback: _placeholder(r),
                                        )
                                      : _placeholder(r),
                                  // Glass overlay on hover
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withValues(alpha: 0.5),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Like badge
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: GestureDetector(
                                      onTap: () => likedCubit.toggleLike(albumItem),
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.black.withValues(alpha: 0.35),
                                        ),
                                        child: Icon(
                                          isAlbumLiked ? Icons.favorite : Icons.favorite_border,
                                          color: isAlbumLiked ? Colors.red : Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            a.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: r.footerSize - 1,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          // Offline tracks
          if (!_isOnline) ...[
            SizedBox(height: r.spacingM),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.spacingS),
              child: Row(children: [
                Icon(Icons.cloud_off, size: r.footerSize,
                  color: Colors.white.withValues(alpha: 0.4)),
                SizedBox(width: 6),
                Text('${loc.setup.downloaded} ${loc.setup.miSpaceSongs.toLowerCase()}',
                  style: TextStyle(fontSize: r.footerSize,
                    color: Colors.white.withValues(alpha: 0.4))),
              ]),
            ),
            SizedBox(height: r.spacingS),
            ..._offlineTracks(likedCubit, dlCubit, r, isDark),
          ],
        ],
      ),
    );
  }

  List<Widget> _offlineTracks(LikeCubit likedCubit, DownloadCubit dlCubit, Responsive r, bool isDark) {
    final tracks = likedCubit.tracks.where((t) {
      return t.artists?.toLowerCase().contains(widget.artistName.toLowerCase()) ?? false;
    }).toList();

    if (tracks.isEmpty) return [];

    final feedItems = tracks.map((t) => FeedItem(
      id: t.id, type: 'track', name: t.name, artists: t.artists,
      coverUrl: t.coverUrl, albumName: t.albumName,
      durationMs: t.durationMs, source: t.source ?? widget.source,
    )).toList();

    return feedItems.asMap().entries.map((entry) {
      final feedItem = entry.value;
      final t = tracks[entry.key];
      final dID = 'track_${normalizeTrackId(t.id)}_${t.source ?? widget.source}';
      void play() => sl<QueueCubit>().playWithContext(feedItems, feedItem);
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: r.spacingXS * 0.5),
        child: TrackCard(
          title: t.name,
          subtitle: t.artists ?? widget.artistName,
          coverUrl: likedCubit.resolveCoverFor(feedItem),
          readyKey: normalizeTrackId(t.id),
          isLiked: true,
          textScale: 1.2,
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

  Widget _placeholder(Responsive r) => Container(
    color: Colors.white.withValues(alpha: 0.06),
    child: Icon(Icons.album, color: Colors.white.withValues(alpha: 0.2), size: r.titleSize * 0.5),
  );
}

/// Futuristic glassmorphism action button.
class _GlassActionBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final bool filled;

  const _GlassActionBtn({
    required this.icon,
    this.onTap,
    this.color,
    this.filled = false,
  });

  @override
  State<_GlassActionBtn> createState() => _GlassActionBtnState();
}

class _GlassActionBtnState extends State<_GlassActionBtn>
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
    final accent = widget.color ?? (isDark ? const Color(0xFF5AF13D) : const Color(0xFF0B5A1E));
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
          return Transform.scale(scale: _scaleAnim.value, child: child);
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
                ? [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 20, spreadRadius: 1)]
                : null,
          ),
          child: Icon(widget.icon, size: 22, color: enabled ? fgColor : fgColor.withValues(alpha: 0.3)),
        ),
      ),
    );
  }
}
