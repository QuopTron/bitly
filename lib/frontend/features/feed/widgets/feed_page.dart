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
          child: BlocBuilder<LikeCubit, LikeState>(
            builder: (context, likeState) {
              return BlocBuilder<DownloadCubit, DownloadCubitState>(
                builder: (context, dlState) {
                  final ds = <String, DownloadState>{};
                  for (final e in dlState.downloads.entries) {
                    ds[e.key] = e.value.state;
                  }
                  return FeedContent(
                    onBg: onBg, glowColor: glowColor,
                    sections: sections, hasContent: hasContent,
                    loading: state.loading, currentDisplayName: _currentDisplayName,
                    likedIds: likeState.likedFingerprints,
                    downloadStates: ds,
                    downloadedFingerprints: dlState.downloadedFingerprints,
                    onToggleLike: _toggleLike, onStartDownload: _startDownload, onBatchDownload: _startBatchDownload,
                    onBatchDelete: _onBatchDelete,
                    onExportPlaylist: _onExportPlaylist,
                    onDeleteTrack: (item) => context.read<DownloadCubit>().deleteTrackResolved(item),
                    onShowInfo: _showInfo, onShowMore: _showMore, onNavigateToItem: _navigateToItem,
                  );
                },
              );
            },
          ),
        ),
      ]);
    });
  }
}


