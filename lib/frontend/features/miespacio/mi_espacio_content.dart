import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import '../../shared/utils/responsive.dart';
import '../../shared/utils/download_strategy.dart';
import '../../shared/widgets/download_options_sheet.dart';
import '../../../backend/services/queue_cubit.dart';
import '../../../injection.dart';
import '../../../backend/services/download_cubit.dart';
import '../../../backend/services/like_cubit.dart';
import '../../../backend/services/item_fingerprint.dart';
import '../../shared/widgets/track_card.dart';
import '../../shared/widgets/grid_card.dart';
import '../../shared/widgets/song_info_modal.dart';
import '../../shared/widgets/add_to_modal.dart';
import '../../shared/widgets/tag_editor_sheet.dart';
import '../../shared/widgets/create_playlist_modal.dart';
import '../../shared/models/feed_models.dart';
import '../../l10n/app_localizations.dart';

enum ItemType { song, playlist, album, artist }

enum ItemOrigin { liked, downloaded, own, none }

class Item {
  final String title;
  final String subtitle;
  final ItemType type;
  final String? coverUrl;
  final String realId;
  final String source;
  final ItemOrigin origin;
  const Item(
    this.title,
    this.subtitle,
    this.type, {
    this.coverUrl,
    this.realId = '',
    this.source = '',
    this.origin = ItemOrigin.none,
  });
}

class MiEspacioContent extends StatelessWidget {
  final bool loading;
  final List<Item> items;
  final int selectedTab;
  final String emptyMessage;
  final Map<String, DownloadState> downloadStates;
  final void Function(Item item) onUnlike;
  final void Function(Item item)? onLike;
  final void Function(Item item)? onItemTap;
  final VoidCallback? onCreatePlaylist;
  final VoidCallback? onCreateFromLiked;
  final VoidCallback? onCreateFromDownloaded;
  final void Function(Item item)? onBatchDownload;
  final void Function(Item item)? onBatchDelete;
  final void Function(Item item)? onRetryBatch;
  final void Function(Item item)? onExportPlaylist;

  /// IDs of items that are currently liked (from LikeCubit.allLiked keys).
  final Set<String> likedIds;

  /// Source-agnostic set of downloaded track fingerprints, for cross-extension
  /// detection of a downloaded track (SpotiFLAC behavior).
  final Set<String> downloadedFingerprints;

  const MiEspacioContent({
    super.key,
    required this.loading,
    required this.items,
    required this.selectedTab,
    required this.emptyMessage,
    this.downloadStates = const {},
    required this.onUnlike,
    this.onLike,
    this.onItemTap,
    this.onCreatePlaylist,
    this.onCreateFromLiked,
    this.onCreateFromDownloaded,
    this.onBatchDownload,
    this.onBatchDelete,
    this.onRetryBatch,
    this.onExportPlaylist,
    this.likedIds = const {},
    this.downloadedFingerprints = const {},
  });

  /// Fallback download state lookup for items whose source is empty
  /// (e.g. liked albums from DB before the source fix). Tries to find
  /// any download key matching the item type + ID across all sources.
  /// Resolves a cover for a grid card: prefers the item's own cover, else
  /// falls back to the locally-saved cover of the liked item (so a liked /
  /// saved card never goes gray when its URL is empty).
  String? _resolveCover(BuildContext context, Item item) {
    if (item.coverUrl?.isNotEmpty == true) return item.coverUrl;
    try {
      final likeCubit = context.read<LikeCubit>();
      final feed = FeedItem(
        id: item.realId,
        name: item.title,
        artists: item.subtitle,
        type: switch (item.type) {
          ItemType.song => 'track',
          ItemType.playlist => 'playlist',
          ItemType.album => 'album',
          ItemType.artist => 'artist',
        },
        source: item.source,
      );
      final local = likeCubit.localCoverFor(feed);
      if (local != null && local.isNotEmpty) return local;
      final resolved = likeCubit.resolveCoverFor(feed);
      if (resolved != null && resolved.isNotEmpty) return resolved;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Download state for a track: exact source-keyed state when present, else
  /// source-agnostic prefix scan (any source for same track ID), then
  /// fingerprint fallback (same track downloaded under another extension).
  DownloadState _trackStateFor(FeedItem item, String id) {
    final s = downloadStates[id];
    if (s != null && s != DownloadState.none) return s;
    // Prefix scan: find any download key matching the track ID across all sources
    final normId = normalizeTrackId(item.id);
    final prefix = 'track_${normId}_';
    for (final key in downloadStates.keys) {
      if (key.startsWith(prefix)) {
        final state = downloadStates[key];
        if (state != null && state != DownloadState.none) return state;
      }
    }
    // Fingerprint fallback: source-agnostic match by name+artist
    return downloadedFingerprints.contains(fingerprintItem(item))
        ? DownloadState.completed
        : DownloadState.none;
  }

  static DownloadState _resolveDownloadState(
    Map<String, DownloadState> states,
    String type,
    Item item,
  ) {
    final id = '${type}_${normalizeTrackId(item.realId)}_${item.source}';
    final ds = states[id];
    if (ds != null) return ds;
    // Fallback por prefijo SIEMPRE: el batch de descarga puede tener un
    // source escrito distinto al del item ("deezer" vs "deezer-web", o un
    // batch restaurado de la BD con source vacío), así que buscamos cualquier
    // estado del mismo tipo + ID sin importar el source.
    final prefix = '${type}_${normalizeTrackId(item.realId)}_';
    for (final key in states.keys) {
      if (key.startsWith(prefix)) return states[key]!;
    }
    return DownloadState.none;
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? Colors.white : Colors.black;

    if (loading) {
      return Center(
        child: SizedBox(
          width: r.footerSize + 4,
          height: r.footerSize + 4,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: onBg.withValues(alpha: 0.3),
          ),
        ),
      );
    }

    if (selectedTab == 1 && items.isEmpty) {
      return _emptyPlaylistView(context, r, onBg);
    }
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border,
              size: r.titleSize * 1.5,
              color: onBg.withValues(alpha: 0.12),
            ),
            SizedBox(height: r.spacingM),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: r.footerSize,
                  color: onBg.withValues(alpha: 0.3),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (selectedTab == 0) return _songsView(context, r);
    return _gridView(context, r, _gridType(), onBg);
  }

  Widget _emptyPlaylistView(BuildContext context, Responsive r, Color onBg) {
    final loc = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.queue_music,
            size: r.titleSize * 1.5,
            color: onBg.withValues(alpha: 0.12),
          ),
          SizedBox(height: r.spacingM),
          Text(
            loc.setup.miSpaceEmptyPlaylists,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.footerSize,
              color: onBg.withValues(alpha: 0.3),
            ),
          ),
          SizedBox(height: r.spacingM),
          _createButton(context, r, loc, onBg),
        ],
      ),
    );
  }

  String _gridType() {
    switch (selectedTab) {
      case 1:
        return 'playlist';
      case 2:
        return 'album';
      case 3:
        return 'artist';
      default:
        return '';
    }
  }

  Widget _miniButton(
    BuildContext context,
    Responsive r,
    IconData icon,
    String label,
    VoidCallback onTap,
    Color onBg,
    Color iconColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: r.spacingS,
          vertical: r.spacingXS,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: iconColor.withValues(alpha: 0.2)),
          color: iconColor.withValues(alpha: 0.06),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: r.footerSize - 2, color: iconColor),
            SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(fontSize: r.footerSize - 2, color: iconColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _createButton(
    BuildContext context,
    Responsive r,
    AppLocalizations loc,
    Color onBg,
  ) {
    return GestureDetector(
      onTap: () async {
        final id = await showCreatePlaylistModal(context);
        if (id != null) onCreatePlaylist?.call();
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: r.spacingL,
          vertical: r.spacingS,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: onBg.withValues(alpha: 0.15)),
          color: onBg.withValues(alpha: 0.05),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add,
              size: r.footerSize,
              color: onBg.withValues(alpha: 0.5),
            ),
            SizedBox(width: r.spacingXS),
            Text(
              loc.setup.addToPlaylist,
              style: TextStyle(
                fontSize: r.footerSize,
                color: onBg.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _songsView(BuildContext context, Responsive r) {
    final likeCubit = context.read<LikeCubit>();
    final feedItems =
        items
            .map(
              (s) => FeedItem(
                id: s.realId,
                type: 'track',
                name: s.title,
                artists: s.subtitle,
                coverUrl: s.coverUrl,
                source: s.source.isNotEmpty ? s.source : null,
              ),
            )
            .toList();
    return ListView(
      padding: EdgeInsets.all(r.spacingS),
      children:
          feedItems.asMap().entries.map((entry) {
            final feedItem = entry.value;
            final s = items[entry.key];
            final id =
                'track_${normalizeTrackId(feedItem.id)}_${feedItem.source ?? ''}';
            // Prefer download's local cover (saveCover) over remote URL
            final downloadCover = context.read<DownloadCubit>().localTrackCover(
              feedItem.id,
              feedItem.source ?? '',
            );
            final likedCover = likeCubit.resolveCoverFor(feedItem);
            final resolvedCover =
                downloadCover ?? likedCover ?? feedItem.coverUrl;
            return Padding(
              padding: EdgeInsets.only(bottom: r.spacingXS),
              child: TrackCard(
                title: feedItem.name,
                subtitle: feedItem.artists ?? '',
                coverUrl: resolvedCover,
                readyKey: normalizeTrackId(feedItem.id),
                isLiked: likedIds.any(
                  (rawId) =>
                      normalizeTrackId(rawId) == normalizeTrackId(feedItem.id),
                ),
                onLike: () {
                  final isLiked = likedIds.any(
                    (rawId) =>
                        normalizeTrackId(rawId) ==
                        normalizeTrackId(feedItem.id),
                  );
                  if (isLiked) {
                    onUnlike(s);
                  } else {
                    onLike?.call(s);
                  }
                },
                downloadState: _trackStateFor(feedItem, id),
                // textScale 1.2 + info/more: mismas dimensiones y acciones que
                // Feed/Search para que la track card se vea igual en todo lado.
                textScale: 1.2,
                onTap:
                    () => sl<QueueCubit>().playWithContext(
                      feedItems,
                      feedItem,
                    ),
                onDownload: () => _openDownload(context, s),
                onDelete:
                    context.read<DownloadCubit>().downloadStateFor(id).state ==
                            DownloadState.completed
                        ? () => context
                            .read<DownloadCubit>()
                            .deleteTrackDownload(s.realId, s.source)
                        : null,
                onInfo: () => showSongInfoModal(context, feedItem),
                onMore: () => showAddToModal(context, feedItem),
                onShare:
                    () => SharePlus.instance.share(
                      ShareParams(text: '🎵 ${s.title} — ${s.subtitle}'),
                    ),
                onEditTags:
                    context.read<DownloadCubit>().downloadStateFor(id).state ==
                            DownloadState.completed
                        ? () async {
                            final path = await context
                                .read<DownloadCubit>()
                                .getTrackFilePath(s.realId, s.source);
                            if (path != null && context.mounted) {
                              showTagEditor(
                                context,
                                filePath: path,
                                title: s.title,
                                artist: s.subtitle,
                              );
                            }
                          }
                        : null,
              ),
            );
          }).toList(),
    );
  }

  void _openDownload(BuildContext context, Item item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDownloadOptions(
      context,
      FeedItem(
        id: item.realId,
        type: 'track',
        name: item.title,
        artists: item.subtitle,
        coverUrl: item.coverUrl,
        source: item.source,
      ),
      isDark,
      // Manual tap on the download icon in Mi Espacio: always let the user pick
      // quality, even if quick-download is enabled globally.
      ignoreQuickDownload: true,
    );
  }

  /// Compact origin badge for grid cards (liked/downloaded/own). Falls back to
  /// the existing like heart + download indicator when the origin is unknown.
  Widget? _originBadge(BuildContext context, Item item) {
    if (item.origin == ItemOrigin.none) return null;
    final r = Responsive(context);
    final size = r.footerSize - 4;
    final (icon, color, label) = switch (item.origin) {
      ItemOrigin.liked => (Icons.favorite, Colors.redAccent, null),
      ItemOrigin.downloaded => (Icons.download, const Color(0xFF4CAF50), null),
      ItemOrigin.own => (
        Icons.person_pin,
        const Color(0xFF4CAF50),
        AppLocalizations.of(context).setup.miSpaceOwned,
      ),
      ItemOrigin.none => (Icons.music_note, Colors.white70, null),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.black.withValues(alpha: 0.55),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: size, color: color),
          if (label != null) ...[
            SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: size - 2,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gridView(
    BuildContext parentCtx,
    Responsive r,
    String type,
    Color onBg,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final avail = constraints.maxWidth - 2 * r.spacingS * 0.5;
        final crossAxisCount =
            avail > 700
                ? 4
                : avail > 340
                ? 3
                : 2;
        final gap = r.spacingXS;
        final cardWidth = (avail - (crossAxisCount - 1) * gap) / crossAxisCount;
        // GridCard is a Stack(fit: expand) that needs a BOUNDED height (a Wrap
        // inside a scroll view only gives infinite height → layout assertion).
        // Reserve the same info-block height GridCard computes internally so
        // the cover renders roughly square: coverSide = cardWidth (minus pad)
        // + info block + internal gaps.
        // Mismo cálculo que GridCard._infoHeight pero con textScale 1.2 (el
        // que usan Feed/Search) para que las tarjetas de Mi Espacio tengan las
        // mismas proporciones que en el resto de la app.
        const ts = 1.2;
        final infoH =
            r.spacingS * 2 +
            r.footerSize * 1.3 +
            r.spacingXS +
            (r.footerSize + 4) * ts * 2 * 1.18 +
            3 +
            (r.footerSize + 1) * ts * 1.18;
        final cardHeight = cardWidth + infoH;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: r.spacingS * 0.5, vertical: r.spacingS),
          child: Column(
            children: [
              if (type == 'playlist')
                Padding(
                  padding: EdgeInsets.only(bottom: r.spacingS),
                  child: Row(
                    children: [
                      _createButton(
                        context,
                        r,
                        AppLocalizations.of(context),
                        onBg,
                      ),
                      if (onCreateFromLiked != null) ...[
                        SizedBox(width: r.spacingXS),
                        _miniButton(
                          context,
                          r,
                          Icons.favorite,
                          AppLocalizations.of(context).setup.likedSongs,
                          onCreateFromLiked!,
                          onBg,
                          Colors.redAccent,
                        ),
                      ],
                      if (onCreateFromDownloaded != null) ...[
                        SizedBox(width: r.spacingXS),
                        _miniButton(
                          context,
                          r,
                          Icons.download_done,
                          AppLocalizations.of(context).setup.downloaded,
                          onCreateFromDownloaded!,
                          onBg,
                          const Color(0xFF4CAF50),
                        ),
                      ],
                    ],
                  ),
                ),
              Wrap(
                spacing: gap,
                runSpacing: r.spacingS,
                children:
                    items.map((item) {
                      // likedIds uses raw IDs (with prefixes), so normalize for matching
                      final isItemLiked = likedIds.any(
                        (rawId) =>
                            normalizeTrackId(rawId) ==
                            normalizeTrackId(item.realId),
                      );
                      return SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: GridCard(
                          type: type,
                          title: item.title,
                          subtitle: item.subtitle,
                          coverUrl: _resolveCover(context, item),
                          // Mismo textScale que Feed/Search: tarjetas del mismo
                          // tamaño en toda la app (fuera de setup).
                          textScale: 1.2,
                          isLiked: isItemLiked,
                          cornerBadge:
                              type != 'artist'
                                  ? _originBadge(context, item)
                                  : null,
                          showThirdAction:
                              type != 'album' && type != 'playlist',
                          showDownloadAction: !(item.origin == ItemOrigin.own),
                          onTap:
                              onItemTap != null ? () => onItemTap!(item) : null,
                          onLike: () {
                            if (isItemLiked) {
                              onUnlike(item);
                            } else {
                              onLike?.call(item);
                            }
                          },
                          downloadState: _resolveDownloadState(
                            downloadStates,
                            type,
                            item,
                          ),
                          onDownload:
                              (type == 'album' || type == 'playlist')
                                  ? (onBatchDownload != null
                                      ? () => onBatchDownload!(item)
                                      : () => _openDownload(context, item))
                                  : null,
                          onDelete:
                              (type == 'album' || type == 'playlist')
                                  ? (onBatchDelete != null
                                      ? () => onBatchDelete!(item)
                                      : null)
                                  : null,
                          onRetry:
                              (type == 'album' || type == 'playlist')
                                  ? (onRetryBatch != null
                                      ? () => onRetryBatch!(item)
                                      : null)
                                  : null,
                          onExport:
                              (type == 'playlist' || type == 'album') &&
                                      onExportPlaylist != null
                                  ? () => onExportPlaylist!(item)
                                  : null,
                        ),
                      );
                    }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
