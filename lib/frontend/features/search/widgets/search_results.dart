import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import '../../../shared/utils/download_strategy.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/widgets/shimmer_skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/feed_models.dart';
import '../../../../backend/services/item_fingerprint.dart';
import '../../../../backend/services/like_cubit.dart';
import '../../../../backend/services/queue_cubit.dart';
import '../../../../injection.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/track_card.dart';
import '../../../shared/widgets/grid_card.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/download_indicator.dart';
import '../../../shared/constants/source_constants.dart';

class SearchResultsBody extends StatelessWidget {
  final String? selectedType;
  /// The active search source; empty means "Todas" (every extension). In that
  /// mode results are grouped by source (extension) so each one shows its own
  /// section — matching SpotiFLAC's "separado entre extensiones".
  final String selectedSource;
  final List<FeedItem> results;
  final bool loading;
  final bool hasSearched;
  final String? error;
  final Set<String> likedIds;
  final Map<String, DownloadState> downloadStates;
  /// Source-agnostic set of downloaded track fingerprints. Lets a track
  /// downloaded under one extension show as downloaded under every other
  /// extension too (SpotiFLAC behavior).
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

  const SearchResultsBody({
    super.key,
    required this.selectedType,
    required this.selectedSource,
    required this.results,
    required this.loading,
    required this.hasSearched,
    this.error,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? Colors.white : Colors.black;
    final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;

    if (loading) {
      return FeedSkeleton();
    }
    if (error != null) {
      return Center(child: Text(error!, style: TextStyle(color: Colors.redAccent, fontSize: r.subtitleSize)));
    }
    if (results.isEmpty && hasSearched) {
      return Center(child: Text(loc.setup.noResults, style: TextStyle(fontSize: r.subtitleSize, color: onBg.withValues(alpha: 0.4))));
    }

    // Default (no chip active): show every category grouped in its own labelled
    // section, like SpotiFLAC, so nothing (e.g. playlists) gets lost behind a
    // filter. Tapping a chip narrows the view to that single category.
    if (selectedType == null) {
      final grouped = <String, List<FeedItem>>{
        'tracks': [], 'artists': [], 'albums': [], 'playlists': [],
      };
      for (final it in results) {
        final cat = _category(it.type);
        if (grouped[cat] != null) grouped[cat]!.add(it);
      }
      const order = ['tracks', 'artists', 'albums', 'playlists'];
      final children = <Widget>[];
      for (final cat in order) {
        final items = grouped[cat]!;
        if (items.isEmpty) continue;
        children.add(_sectionHeader(context, cat, items.length, r, glowColor, onBg));
        if (cat == 'tracks')
          children.addAll(_trackCards(context, items, r));
        else
          children.add(_gridSection(context, items, r,
              glowColor: glowColor, onBg: onBg, title: null));
      }
      if (children.isEmpty) {
        return Center(child: Text(loc.setup.noResults, style: TextStyle(fontSize: r.subtitleSize, color: onBg.withValues(alpha: 0.4))));
      }
      return ListView(
        padding: EdgeInsets.symmetric(vertical: r.spacingS),
        children: children,
      );
    }

    // "Todas": group results by SOURCE (extension), each in its own labelled
    // section, so every extension that returned something is visible instead of
    // getting lost behind a single primary source. Within each source the items
    // of the active category (selectedType) are shown — tracks as a list, the
    // rest as a grid.
    if (selectedSource.isEmpty) {
      final bySource = <String, List<FeedItem>>{};
      for (final it in results) {
        if (selectedType != null && _category(it.type) != selectedType) continue;
        final src = it.source ?? 'unknown';
        (bySource[src] ??= []).add(it);
      }
      final children = <Widget>[];
      for (final entry in bySource.entries) {
        if (entry.value.isEmpty) continue;
        children.add(_sourceHeader(context, entry.key, entry.value.length, r, glowColor, onBg));
        if (selectedType == 'tracks')
          children.addAll(_trackCards(context, entry.value, r));
        else
          children.add(_gridSection(context, entry.value, r,
              glowColor: glowColor, onBg: onBg, title: null));
      }
      if (children.isEmpty) {
        return Center(child: Text(loc.setup.noResults, style: TextStyle(fontSize: r.subtitleSize, color: onBg.withValues(alpha: 0.4))));
      }
      return ListView(
        padding: EdgeInsets.symmetric(vertical: r.spacingS),
        children: children,
      );
    }

    // Single category active: show only that one.
    final items = results.where((it) => _category(it.type) == selectedType).toList();
    if (items.isEmpty && hasSearched) {
      return Center(child: Text(loc.setup.noResults, style: TextStyle(fontSize: r.subtitleSize, color: onBg.withValues(alpha: 0.4))));
    }
    if (selectedType == 'tracks') {
      return ListView(
        padding: EdgeInsets.symmetric(vertical: r.spacingS),
        children: [..._trackCards(context, items, r)],
      );
    }
    return ListView(
      padding: EdgeInsets.symmetric(vertical: r.spacingS),
      children: [
        _gridSection(context, items, r,
            glowColor: glowColor, onBg: onBg, title: _categoryLabel(loc, selectedType!)),
      ],
    );
  }

  static const _iconByCat = <String, IconData>{
    'tracks': Icons.music_note,
    'artists': Icons.person,
    'albums': Icons.album,
    'playlists': Icons.playlist_play,
  };

  Widget _sectionHeader(BuildContext context, String cat, int count, Responsive r,
      Color glowColor, Color onBg) {
    return Padding(
      padding: EdgeInsets.fromLTRB(r.spacingS + 4, r.spacingM, r.spacingS, r.spacingS),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              glowColor.withValues(alpha: 0.3),
              glowColor.withValues(alpha: 0.06),
            ]),
            border: Border.all(color: glowColor.withValues(alpha: 0.3), width: 0.8),
          ),
          child: Icon(_iconByCat[cat] ?? Icons.search, size: 16, color: glowColor),
        ),
        SizedBox(width: r.spacingS),
        Text(_categoryLabel(AppLocalizations.of(context), cat),
          style: TextStyle(fontSize: r.subtitleSize + 4, fontWeight: FontWeight.bold, color: onBg)),
        SizedBox(width: r.spacingXS),
        Text('($count)', style: TextStyle(fontSize: r.footerSize + 1,
          color: onBg.withValues(alpha: 0.4), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _categoryLabel(AppLocalizations loc, String cat) {
    switch (cat) {
      case 'tracks': return loc.setup.searchTracks;
      case 'artists': return loc.setup.searchArtists;
      case 'albums': return loc.setup.searchAlbums;
      case 'playlists': return loc.setup.searchPlaylists;
      default: return cat;
    }
  }

  /// Header for a "Todas" source section (extension name + result count).
  Widget _sourceHeader(BuildContext context, String source, int count,
      Responsive r, Color glowColor, Color onBg) {
    return Padding(
      padding: EdgeInsets.fromLTRB(r.spacingS + 4, r.spacingM, r.spacingS, r.spacingS),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              glowColor.withValues(alpha: 0.3),
              glowColor.withValues(alpha: 0.06),
            ]),
            border: Border.all(color: glowColor.withValues(alpha: 0.3), width: 0.8),
          ),
          child: Icon(sourceIcons[source] ?? Icons.cloud_outlined, size: 16, color: glowColor),
        ),
        SizedBox(width: r.spacingS),
        Text(sourceDisplayName(source),
          style: TextStyle(fontSize: r.subtitleSize + 4, fontWeight: FontWeight.bold, color: onBg)),
        SizedBox(width: r.spacingXS),
        Text('($count)', style: TextStyle(fontSize: r.footerSize + 1,
          color: onBg.withValues(alpha: 0.4), fontWeight: FontWeight.w500)),
      ]),
    );
  }

  static String _category(String raw) {
    switch (raw) {
      case 'track': case 'tracks': return 'tracks';
      case 'artist': case 'artists': return 'artists';
      case 'album': case 'albums': return 'albums';
      case 'playlist': case 'playlists': return 'playlists';
      default: return raw;
    }
  }

  /// Download state for a track card. Uses the exact source-keyed state when
  /// present (in-progress/interrupted/completed), else falls back to the
  /// source-agnostic fingerprint so the same track downloaded under another
  /// extension still reads as "downloaded" here.
  DownloadState _trackDownloadState(String fp, String id) {
    final s = downloadStates[id];
    if (s != null && s != DownloadState.none) return s;
    return downloadedFingerprints.contains(fp)
        ? DownloadState.completed
        : DownloadState.none;
  }

  /// Track cards as individual ListView children — matches Feed layout
  /// exactly so cards render at the same width and spacing.
  List<Widget> _trackCards(BuildContext context, List<FeedItem> items, Responsive r) {
    return items.map((item) {
      final fp = fingerprintItem(item);
      final id = '${item.type}_${normalizeTrackId(item.id)}_${item.source}';
      void play() => sl<QueueCubit>().playWithContext(items, item);
      final resolvedCover = context.read<LikeCubit>().resolveCoverFor(item);
      return TrackCard(
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
      );
    }).toList();
  }

  Widget _gridSection(BuildContext context, List<FeedItem> items, Responsive r,
      {Color? glowColor, Color? onBg, String? title}) {
    return LayoutBuilder(
      builder: (_, constraints) {
        // Mismo ancho disponible que el grid del Feed para que las tarjetas
        // tengan exactamente el mismo tamaño en Search que en Home.
        final avail = constraints.maxWidth - 2 * r.spacingS;
        final crossAxisCount = avail > 700 ? 4 : avail > 340 ? 3 : 2;
        final gap = r.spacingXS;
        // Uniform square cells -> every card same size, no ragged rows.
        return Column(children: [
          if (title != null) Padding(
            padding: EdgeInsets.fromLTRB(r.spacingS + 4, r.spacingM, r.spacingS, r.spacingS),
            child: Row(children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    (glowColor ?? Colors.green).withValues(alpha: 0.3),
                    (glowColor ?? Colors.green).withValues(alpha: 0.06),
                  ]),
                  border: Border.all(color: (glowColor ?? Colors.green).withValues(alpha: 0.3), width: 0.8),
                ),
                child: Center(child: Icon(Icons.folder_open, size: 14, color: glowColor ?? Colors.green)),
              ),
              SizedBox(width: r.spacingS),
              Text(title, style: TextStyle(fontSize: r.subtitleSize + 4, fontWeight: FontWeight.bold, color: onBg)),
            ]),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: r.spacingS * 0.5),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              // Misma proporción que el grid del Feed.
              childAspectRatio: 0.72,
            ),
            itemCount: items.length,
            itemBuilder: (_, index) {
              final item = items[index];
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
                showThirdAction: item.type == 'track',
                onTap: item.type != 'track' ? () => onNavigateToItem(item) : null,
              );
            },
          ),
        ]);
      },
    );
  }
}

class SearchRecentList extends StatelessWidget {
  final List<String> searches;
  final ValueChanged<String> onSearchTap;
  final VoidCallback onClearAll;
  final ValueChanged<String> onRemove;

  const SearchRecentList({
    super.key,
    required this.searches,
    required this.onSearchTap,
    required this.onClearAll,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? Colors.white : Colors.black;
    final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;
    final loc = AppLocalizations.of(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(r.spacingS, r.spacingM, r.spacingS, r.spacingS),
      children: [
        Row(children: [
          Icon(Icons.history, size: r.footerSize + 4, color: glowColor.withValues(alpha: 0.5)),
          SizedBox(width: r.spacingXS),
          Text(loc.setup.recentSearches, style: TextStyle(fontSize: r.subtitleSize + 3, fontWeight: FontWeight.bold, color: onBg)),
          const Spacer(),
          GestureDetector(
            onTap: onClearAll,
            child: Text(loc.setup.clear, style: TextStyle(fontSize: r.footerSize, color: glowColor.withValues(alpha: 0.7))),
          ),
        ]),
        SizedBox(height: r.spacingM),
        ...searches.map((q) => Padding(
          padding: EdgeInsets.only(bottom: r.spacingXS),
          child: GestureDetector(
            onTap: () => onSearchTap(q),
            child: GlassContainer(
              borderRadius: 12,
              borderColor: onBg.withValues(alpha: 0.06),
              bgColor: onBg.withValues(alpha: 0.02),
              padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingS),
              child: Row(children: [
                Icon(Icons.search, size: r.footerSize + 4, color: onBg.withValues(alpha: 0.3)),
                SizedBox(width: r.spacingM),
                Expanded(
                  child: Text(q, style: TextStyle(fontSize: r.subtitleSize, color: onBg.withValues(alpha: 0.7)),
                    overflow: TextOverflow.ellipsis),
                ),
                GestureDetector(
                  onTap: () => onRemove(q),
                  child: Icon(Icons.close, size: r.footerSize, color: onBg.withValues(alpha: 0.2)),
                ),
              ]),
            ),
          ),
        )),
      ],
    );
  }
}

class SearchUrlPaste extends StatelessWidget {
  const SearchUrlPaste({super.key});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? Colors.white : Colors.black;
    final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;
    final loc = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.spacingL),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.link, size: r.titleSize * 1.5, color: onBg.withValues(alpha: 0.15)),
          SizedBox(height: r.spacingM),
          Text(loc.setup.searchPasteHint,
            style: TextStyle(fontSize: r.subtitleSize, color: onBg.withValues(alpha: 0.4)),
            textAlign: TextAlign.center),
          SizedBox(height: r.spacingM),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _badge(Icons.play_circle_fill, 'YouTube', r, glowColor, onBg),
            SizedBox(width: r.spacingS),
            _badge(Icons.music_note, 'Spotify', r, glowColor, onBg),
          ]),
        ]),
      ),
    );
  }

  Widget _badge(IconData icon, String label, Responsive r, Color glowColor, Color onBg) {
    return GlassContainer(
      borderRadius: 20,
      borderColor: glowColor.withValues(alpha: 0.2),
      bgColor: glowColor.withValues(alpha: 0.06),
      padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingXS),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: r.footerSize + 2, color: glowColor),
        SizedBox(width: r.spacingXS),
        Text(label, style: TextStyle(fontSize: r.footerSize + 2, color: glowColor, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}


