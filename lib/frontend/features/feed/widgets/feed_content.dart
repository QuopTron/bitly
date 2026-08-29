import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/utils/download_strategy.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/feed_titles.dart';
import '../../../shared/models/feed_models.dart';
import '../../../../backend/services/item_fingerprint.dart';
import '../../../../backend/services/like_cubit.dart';
import '../../../../backend/services/queue_cubit.dart';
import '../../../../injection.dart';
import '../../../shared/widgets/track_card.dart';
import '../../../shared/widgets/grid_card.dart';
import '../../../shared/widgets/download_indicator.dart';


class FeedContent extends StatelessWidget {
  final Color onBg;
  final Color glowColor;
  final List<FeedSection> sections;
  final bool hasContent;
  final bool loading;
  final String currentDisplayName;
  final Set<String> likedIds;
  final Map<String, DownloadState> downloadStates;
  /// Source-agnostic set of downloaded track fingerprints. Makes a track
  /// downloaded under one extension read as downloaded under every other one.
  final Set<String> downloadedFingerprints;

  final void Function(String id, [FeedItem? item]) onToggleLike;
  final void Function(FeedItem item) onStartDownload;
  final void Function(FeedItem item)? onDeleteTrack;
  final void Function(FeedItem item)? onBatchDownload;
  final void Function(FeedItem item)? onBatchDelete;
  final void Function(FeedItem item)? onExportPlaylist;
  final void Function(BuildContext context, FeedItem item) onShowInfo;
  final void Function(BuildContext context, FeedItem item) onShowMore;
  final void Function(FeedItem item) onNavigateToItem;

  const FeedContent({
    super.key,
    required this.onBg,
    required this.glowColor,
    required this.sections,
    required this.hasContent,
    required this.loading,
    required this.currentDisplayName,
    required this.likedIds,
    required this.downloadStates,
    this.downloadedFingerprints = const {},
    required this.onToggleLike,
    required this.onStartDownload,
    this.onDeleteTrack,
    this.onBatchDownload,
    this.onBatchDelete,
    this.onExportPlaylist,
    required this.onShowInfo,
    required this.onShowMore,
    required this.onNavigateToItem,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final r = Responsive(context);

    if (loading) return const Center(child: CircularProgressIndicator());
    if (!hasContent) {
      return Center(child: Padding(
        padding: EdgeInsets.all(r.spacingXL),
        child: Text(loc.setup.feedNoContent, style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.4))),
      ));
    }

    final children = <Widget>[
      if (currentDisplayName.isNotEmpty && sections.any((s) => s.items.isNotEmpty))
        Padding(
          padding: EdgeInsets.only(left: r.spacingXS, bottom: r.spacingS),
          child: Row(children: [
            Icon(Icons.wifi_tethering, size: r.footerSize, color: glowColor.withValues(alpha: 0.6)),
            SizedBox(width: r.spacingXS),
            Text(currentDisplayName, style: TextStyle(fontSize: r.footerSize, fontWeight: FontWeight.w600, color: glowColor.withValues(alpha: 0.7))),
          ]),
        ),
      ..._buildTrackCards(context, r),
      ..._buildGridCards(context, r),
    ];

    // Lazy builder + shrinkWrap grids avoid the RenderSliverList scroll-extent
    // assertion that crashes when a Wrap (variable-height layout) is placed
    // directly inside a SliverList.
    return ListView.builder(
      padding: EdgeInsets.all(r.spacingS),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }

  List<Widget> _buildTrackCards(BuildContext context, Responsive r) {
    final loc = AppLocalizations.of(context);
    final ts = sections.where((s) => s.items.any((i) => i.type == 'track')).toList();
    final ws = <Widget>[];
    for (final section in ts) {
      final tracks = section.items.where((i) => i.type == 'track').take(10).toList();
      if (tracks.isEmpty) continue;
      if (section.title.isNotEmpty && ts.length > 1) {
        ws.add(Padding(
          padding: EdgeInsets.only(left: r.spacingXS, top: r.spacingXS, bottom: r.spacingXS),
          child: Text(localizeFeedTitle(loc, section.title), style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w600, color: onBg))));
      }
      for (final item in tracks) {
        final fp = fingerprintItem(item);
        final id = 'track_${normalizeTrackId(item.id)}_${item.source}';
        final resolvedCover = context.read<LikeCubit>().resolveCoverFor(item);
        void play() => sl<QueueCubit>().playWithContext(tracks, item);
        ws.add(TrackCard(
          title: item.name, subtitle: item.artists ?? '', coverUrl: resolvedCover,
          textScale: 1.2, readyKey: normalizeTrackId(item.id),
          isLiked: likedIds.contains(fp), onLike: () => onToggleLike(id, item),
          downloadState: _trackDownloadState(fp, id),
                      onDownload: () => onStartDownload(item),
          onDelete: onDeleteTrack != null ? () => onDeleteTrack!(item) : null,
          onInfo: () => onShowInfo(context, item),
          onMore: () => onShowMore(context, item),
          onTap: play,
          onShare: () => SharePlus.instance.share(ShareParams(
            text: item.albumName != null
                ? '🎵 ${item.name} — ${item.artists ?? ''}\n💿 ${item.albumName}'
                : '🎵 ${item.name} — ${item.artists ?? ''}',
          )),
        ));
      }
    }
    return ws;
  }

  /// Download state for a track card: exact source-keyed state when present,
  /// else source-agnostic fingerprint fallback (SpotiFLAC-style detection).
  DownloadState _trackDownloadState(String fp, String id) {
    final s = downloadStates[id];
    if (s != null && s != DownloadState.none) return s;
    return downloadedFingerprints.contains(fp)
        ? DownloadState.completed
        : DownloadState.none;
  }

  List<Widget> _buildGridCards(BuildContext context, Responsive r) {
    return sections.where((s) => s.items.any((i) => i.type != 'track'))
      .map((s) {
        final gridItems = s.items.where((i) => i.type != 'track').toList();
        return Padding(
          padding: EdgeInsets.only(bottom: r.spacingM),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: EdgeInsets.only(left: r.spacingXS, bottom: r.spacingXS),
              child: Text(localizeFeedTitle(AppLocalizations.of(context), s.title), style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w600, color: onBg))),
            LayoutBuilder(builder: (context, constraints) {
              final avail = constraints.maxWidth - 2 * r.spacingS;
              final crossAxisCount = avail > 700 ? 4 : avail > 340 ? 3 : 2;
              final gap = r.spacingXS;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: r.spacingS),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: gap,
                    crossAxisSpacing: gap,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: gridItems.length,
                  itemBuilder: (context, i) {
                    final item = gridItems[i];
                    final fp = fingerprintItem(item);
                    final id = '${item.type}_${normalizeTrackId(item.id)}_${item.source}';
                    final resolvedCover = context.read<LikeCubit>().resolveCoverFor(item);
                    return GridCard(
                      type: item.type, title: item.name, subtitle: item.artists ?? '', coverUrl: resolvedCover,
                      textScale: 1.2,
                      isLiked: likedIds.contains(fp), onLike: () => onToggleLike(id, item),
                      downloadState: downloadStates[id] ?? DownloadState.none,
                      onDownload: (item.type == 'album' || item.type == 'playlist')
                          ? (onBatchDownload != null
                              ? () => onBatchDownload!(item)
                              : () => onStartDownload(item))
                          : () => onStartDownload(item),
                      onDelete: (item.type == 'album' || item.type == 'playlist')
                          ? (onBatchDelete != null ? () => onBatchDelete!(item) : null)
                          : null,
                      onExport: (item.type == 'playlist' || item.type == 'album') && onExportPlaylist != null
                          ? () => onExportPlaylist!(item)
                          : null,
                      onMore: () => onShowMore(context, item),
                      onTap: item.type != 'track' ? () => onNavigateToItem(item) : null,
                    );
                  },
                ),
              );
            }),
          ]),
        );
      }).toList();
  }
}


