import 'package:flutter/material.dart';
import '../../../shared/models/feed_models.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/utils/download_strategy.dart';
import '../../../shared/widgets/track_card.dart';
import '../../../shared/widgets/grid_card.dart';
import '../../../shared/widgets/download_indicator.dart';

class FeedPreviewContent extends StatelessWidget {
  final List<FeedSection> sections;
  final bool loading;
  final String selectedSource;
  final String currentDisplayName;
  final Set<String> likedIds;
  final Map<String, DownloadState> downloadStates;
  final ValueChanged<String> onToggleLike;
  final ValueChanged<String> onDownload;
  final void Function(BuildContext, FeedItem) onShowInfo;
  final void Function(BuildContext, FeedItem) onShowMore;
  final Color onBg;
  final Color glowColor;
  final String emptyLabel;

  const FeedPreviewContent({
    super.key,
    required this.sections,
    required this.loading,
    required this.selectedSource,
    required this.currentDisplayName,
    required this.likedIds,
    required this.downloadStates,
    required this.onToggleLike,
    required this.onDownload,
    required this.onShowInfo,
    required this.onShowMore,
    required this.onBg,
    required this.glowColor,
    required this.emptyLabel,
  });

  List<FeedSection> get _filtered =>
    selectedSource.isEmpty ? sections : sections.where((s) => s.source == selectedSource).toList();

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    final filtered = _filtered;
    final hasContent = filtered.isNotEmpty && filtered.any((s) => s.items.isNotEmpty);
    if (!hasContent) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(Responsive(context).spacingXL),
          child: Text(emptyLabel,
            style: TextStyle(fontSize: Responsive(context).footerSize, color: onBg.withValues(alpha: 0.4))),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(Responsive(context).spacingS),
      children: [
        if (currentDisplayName.isNotEmpty && filtered.any((s) => s.items.isNotEmpty))
          _sourceLabel(context),
        ..._buildTrackCards(context),
        ..._buildGridCards(context),
      ],
    );
  }

  Widget _sourceLabel(BuildContext context) {
    final r = Responsive(context);
    return Padding(
      padding: EdgeInsets.only(left: r.spacingXS, bottom: r.spacingS),
      child: Row(children: [
        Icon(Icons.wifi_tethering, size: r.footerSize, color: glowColor.withValues(alpha: 0.6)),
        SizedBox(width: r.spacingXS),
        Text(currentDisplayName,
          style: TextStyle(fontSize: r.footerSize, fontWeight: FontWeight.w600,
            color: glowColor.withValues(alpha: 0.7))),
      ]),
    );
  }

  List<Widget> _buildTrackCards(BuildContext context) {
    final r = Responsive(context);
    final ts = _filtered.where((s) => s.items.any((i) => i.type == 'track')).toList();
    final ws = <Widget>[];
    for (final section in ts) {
      final tracks = section.items.where((i) => i.type == 'track').take(10).toList();
      if (tracks.isEmpty) continue;
      if (section.title.isNotEmpty && ts.length > 1) {
        ws.add(Padding(
          padding: EdgeInsets.only(left: r.spacingXS, top: r.spacingXS, bottom: r.spacingXS),
          child: Text(section.title,
            style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w600, color: onBg))));
      }
      for (final item in tracks) {
        final id = 'track_${normalizeTrackId(item.id)}_${item.source}';
        ws.add(TrackCard(
          title: item.name, subtitle: item.artists ?? '', coverUrl: item.coverUrl,
          textScale: 1.2,
          isLiked: likedIds.contains(id), onLike: () => onToggleLike(id),
          downloadState: downloadStates[id] ?? DownloadState.none,
          onDownload: () => onDownload(id),
          onInfo: () => onShowInfo(context, item),
          onMore: () => onShowMore(context, item),
          showActions: true,
          actionsEnabled: false,
        ));
      }
    }
    return ws;
  }

  List<Widget> _buildGridCards(BuildContext context) {
    final r = Responsive(context);
    return _filtered.where((s) => s.items.any((i) => i.type != 'track'))
      .map((s) => Padding(
        padding: EdgeInsets.only(bottom: r.spacingM),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: EdgeInsets.only(left: r.spacingXS, bottom: r.spacingXS),
            child: Text(s.title,
              style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w600, color: onBg))),
          LayoutBuilder(
            builder: (context, constraints) {
              final avail = constraints.maxWidth - 2 * r.spacingS;
              final crossAxisCount = avail > 700 ? 4 : avail > 340 ? 3 : 2;
              final gap = r.spacingXS;
              final cardWidth = (avail - (crossAxisCount - 1) * gap) / crossAxisCount;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: r.spacingS),
                child: Wrap(
                  spacing: gap, runSpacing: r.spacingXS,
                  children: s.items.where((i) => i.type != 'track').map((i) {
                    final id = '${i.type}_${normalizeTrackId(i.id)}_${i.source}';
                    return SizedBox(
                      width: cardWidth,
                      child: GridCard(
                        type: i.type, title: i.name, subtitle: i.artists ?? '', coverUrl: i.coverUrl,
                        textScale: 1.2,
                        isLiked: likedIds.contains(id), onLike: () => onToggleLike(id),
                        downloadState: downloadStates[id] ?? DownloadState.none,
                        onDownload: () => onDownload(id),
                        onMore: () => onShowMore(context, i),
                        showActions: true,
                        actionsEnabled: false,
                      ),
                    );
                  }).toList()),
              );
            },
          ),
        ]),
      )).toList();
  }
}


