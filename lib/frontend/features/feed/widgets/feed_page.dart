import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../shared/models/feed_models.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/utils/item_actions.dart';
import '../../../../backend/services/like_cubit.dart';
import '../../../../backend/services/download_cubit.dart';
import '../../../shared/constants/source_constants.dart';
import '../bloc/feed_bloc.dart';
import '../bloc/feed_event.dart';
import '../bloc/feed_state.dart';
import 'feed_header.dart';
import 'feed_content.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  Map<String, String> get _availableSources {
    final state = context.read<FeedBloc>().state;
    // Bubbles come ONLY from the sources the backend home feed actually
    // returned (has content). This removes duplicates (same service registered
    // twice under different names) and hides sources — e.g. webjs extensions
    // without getHomeFeed — that would otherwise show an empty feed.
    final map = <String, String>{};
    for (final s in state.sections) {
      final key = s.source;
      if (key.isEmpty || map.containsKey(key)) continue;
      map[key] = sourceDisplayName(key);
    }
    return map;
  }

  String get _currentDisplayName {
    final state = context.read<FeedBloc>().state;
    return _availableSources[state.selectedSource] ?? sourceDisplayName(state.selectedSource);
  }

  void _toggleLike(String id, [FeedItem? item]) {
    if (item != null) ItemActions.toggleLike(context, item);
  }

  void _startDownload(FeedItem item) => ItemActions.startDownload(context, item);

  Future<void> _startBatchDownload(FeedItem item) =>
      ItemActions.startBatchDownload(context, item);

  void _showInfo(BuildContext context, FeedItem item) => ItemActions.showInfo(context, item);
  void _showMore(BuildContext context, FeedItem item) => ItemActions.showMore(context, item);

  Future<void> _onExportPlaylist(FeedItem item) => ItemActions.exportPlaylist(context, item);

  void _onBatchDelete(FeedItem item) => ItemActions.batchDelete(context, item);

  void _navigateToItem(FeedItem item) => ItemActions.navigateToItem(context, item);

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final onBg = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
    final glowColor = Theme.of(context).brightness == Brightness.dark ? AppColors.greenBright : AppColors.greenMedium;

    return BlocBuilder<FeedBloc, FeedState>(builder: (context, state) {
      final sections = state.selectedSource.isEmpty
          ? state.sections
          : state.sections.where((s) => s.source == state.selectedSource).toList();
      final hasContent = sections.isNotEmpty && sections.any((s) => s.items.isNotEmpty);

      return Column(children: [
        SizedBox(height: r.spacingM),
        FeedHeader(onBg: onBg, glowColor: glowColor, sources: _availableSources),
        SizedBox(height: r.spacingM),
        Expanded(
          child: _FeedBody(
            sections: sections,
            hasContent: hasContent,
            loading: state.loading,
            currentDisplayName: _currentDisplayName,
            onBg: onBg,
            glowColor: glowColor,
            onToggleLike: _toggleLike,
            onStartDownload: _startDownload,
            onBatchDownload: _startBatchDownload,
            onBatchDelete: _onBatchDelete,
            onExportPlaylist: _onExportPlaylist,
            onShowInfo: _showInfo,
            onShowMore: _showMore,
            onNavigateToItem: _navigateToItem,
            onRefresh: () => context.read<FeedBloc>().add(const LoadFeed()),
          ),
        ),
      ]);
    });
  }
}

/// Extracts just the download-state enums (not progress floats) so the feed
/// only rebuilds when a track's DownloadState actually changes — not on every
/// progress tick from the poller.
class _FeedBody extends StatelessWidget {
  final List<FeedSection> sections;
  final bool hasContent;
  final bool loading;
  final String currentDisplayName;
  final Color onBg;
  final Color glowColor;
  final void Function(String, [FeedItem?]) onToggleLike;
  final void Function(FeedItem) onStartDownload;
  final void Function(FeedItem)? onBatchDownload;
  final void Function(FeedItem)? onBatchDelete;
  final void Function(FeedItem)? onExportPlaylist;
  final void Function(BuildContext, FeedItem) onShowInfo;
  final void Function(BuildContext, FeedItem) onShowMore;
  final void Function(FeedItem) onNavigateToItem;
  final VoidCallback? onRefresh;

  const _FeedBody({
    required this.sections, required this.hasContent, required this.loading,
    required this.currentDisplayName, required this.onBg, required this.glowColor,
    required this.onToggleLike, required this.onStartDownload,
    this.onBatchDownload, this.onBatchDelete, this.onExportPlaylist,
    required this.onShowInfo, required this.onShowMore, required this.onNavigateToItem,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LikeCubit, LikeState>(
      buildWhen: (prev, next) => prev.likedFingerprints != next.likedFingerprints,
      builder: (context, likeState) {
        return BlocSelector<DownloadCubit, DownloadCubitState, _DlSnapshot>(
          selector: (dl) => _DlSnapshot(
            dl.downloads.map((k, v) => MapEntry(k, v.state)),
            dl.downloadedFingerprints,
          ),
          builder: (context, dlSnap) {
            return FeedContent(
              onBg: onBg, glowColor: glowColor,
              sections: sections, hasContent: hasContent,
              loading: loading, currentDisplayName: currentDisplayName,
              likedIds: likeState.likedFingerprints,
              downloadStates: dlSnap.states,
              downloadedFingerprints: dlSnap.fingerprints,
              onToggleLike: onToggleLike, onStartDownload: onStartDownload,
              onBatchDownload: onBatchDownload,
              onBatchDelete: onBatchDelete,
              onExportPlaylist: onExportPlaylist,
              onDeleteTrack: (item) => context.read<DownloadCubit>().deleteTrackResolved(item),
              onShowInfo: onShowInfo, onShowMore: onShowMore, onNavigateToItem: onNavigateToItem,
            onRefresh: onRefresh,
            );
          },
        );
      },
    );
  }
}

/// Lightweight snapshot of download state enums + fingerprints.
/// [BlocSelector] uses == to skip rebuilds; this class provides value equality
/// so the feed only rebuilds when states actually change, not on every poll.
class _DlSnapshot {
  final Map<String, DownloadState> states;
  final Set<String> fingerprints;
  const _DlSnapshot(this.states, this.fingerprints);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _DlSnapshot) return false;
    if (states.length != other.states.length) return false;
    for (final e in states.entries) {
      if (other.states[e.key] != e.value) return false;
    }
    return fingerprints.length == other.fingerprints.length &&
           fingerprints.containsAll(other.fingerprints);
  }

  @override
  int get hashCode => Object.hash(states.length, fingerprints.length);
}


