import 'package:flutter/material.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/constants/source_constants.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/track_card.dart';
import '../../../shared/widgets/grid_card.dart';
import '../../../shared/widgets/download_indicator.dart';
import '../../../shared/models/feed_models.dart';
import 'search_tutorial_data.dart';

// ──────────────────────────────────────────────────────────── Header ────────────────────────────────────────────────────────────

class TutorialHeader extends StatelessWidget {
  final Color onBg;
  final String title;
  final String description;

  const TutorialHeader({super.key, required this.onBg, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: EdgeInsets.all(r.spacingS),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onBg.withValues(alpha: 0.04),
          border: Border.all(color: onBg.withValues(alpha: 0.08), width: 0.8),
        ),
        child: Icon(Icons.search, size: r.titleSize * 1.1, color: onBg.withValues(alpha: 0.55)),
      ),
      SizedBox(height: r.spacingS),
      Text(title,
        style: TextStyle(fontSize: r.titleSize, fontWeight: FontWeight.bold, color: onBg, letterSpacing: 1)),
      SizedBox(height: 2),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
        child: Text(description,
          style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.5)),
          textAlign: TextAlign.center),
      ),
    ]);
  }
}

// ────────────────────────────────────────────────────── Source Dropdown ──────────────────────────────────────────────────────

class SourceDropdown extends StatelessWidget {
  final String selectedSource;
  final ValueChanged<String> onSelected;
  final bool isDark;
  final Color onBg;
  final Color glowColor;

  const SourceDropdown({
    super.key,
    required this.selectedSource,
    required this.onSelected,
    required this.isDark,
    required this.onBg,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return PopupMenuButton<String>(
      onSelected: onSelected,
      offset: const Offset(0, 40),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      constraints: const BoxConstraints(maxHeight: 320, minWidth: 180),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(sourceIcons[selectedSource] ?? Icons.search,
            size: r.footerSize + 2, color: glowColor.withValues(alpha: 0.7)),
          Icon(Icons.arrow_drop_down, size: r.footerSize, color: onBg.withValues(alpha: 0.4)),
        ],
      ),
      itemBuilder: (_) => allSources.map((src) {
        final sel = src == selectedSource;
        return PopupMenuItem<String>(
          value: src,
          height: 36,
          child: Row(
            children: [
              Icon(sourceIcons[src] ?? Icons.music_video,
                size: r.footerSize, color: sel ? glowColor : onBg.withValues(alpha: 0.5)),
              SizedBox(width: r.spacingXS),
              Expanded(child: Text(sourceLabels[src] ?? formatId(src),
                style: TextStyle(fontSize: r.footerSize - 1,
                  color: sel ? glowColor : onBg.withValues(alpha: 0.7),
                  fontWeight: sel ? FontWeight.w600 : FontWeight.normal))),
              if (sel) Icon(Icons.check, size: r.footerSize - 2, color: glowColor),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ──────────────────────────────────────────────────────── Type Chips ────────────────────────────────────────────────────────

class TypeChipsRow extends StatelessWidget {
  final String selectedType;
  final List<String> types;
  final ValueChanged<String> onSelected;
  final Color onBg;
  final Color glowColor;
  final String Function(String type) labelBuilder;

  const TypeChipsRow({
    super.key,
    required this.selectedType,
    required this.types,
    required this.onSelected,
    required this.onBg,
    required this.glowColor,
    required this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingS),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: types.map((t) {
          final sel = selectedType == t;
          return Padding(
            padding: EdgeInsets.only(right: r.spacingXS),
            child: GestureDetector(
              onTap: () => onSelected(t),
              child: GlassContainer(
                borderRadius: 20,
                borderColor: sel ? glowColor : onBg.withValues(alpha: 0.1),
                bgColor: sel ? glowColor.withValues(alpha: 0.15) : Colors.transparent,
                padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingXS),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(typeIcons[t] ?? Icons.search, size: r.footerSize,
                    color: sel ? glowColor : onBg.withValues(alpha: 0.5)),
                  SizedBox(width: r.spacingXS),
                  Text(labelBuilder(t),
                    style: TextStyle(fontSize: r.footerSize,
                      color: sel ? glowColor : onBg.withValues(alpha: 0.5),
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                ]),
              ),
            ),
          );
        }).toList()),
      ),
    );
  }
}

// ───────────────────────────────────────────────────── Search Bar ─────────────────────────────────────────────────────

class SearchTutorialBar extends StatelessWidget {
  final TextEditingController controller;
  final Color onBg;
  final Color glowColor;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final Widget? leading;

  const SearchTutorialBar({
    super.key,
    required this.controller,
    required this.onBg,
    required this.glowColor,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return GlassContainer(
      borderRadius: 12,
      borderColor: onBg.withValues(alpha: 0.1),
      margin: EdgeInsets.fromLTRB(r.spacingS, r.spacingS, r.spacingS, 0),
      padding: EdgeInsets.symmetric(horizontal: r.spacingM),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(fontSize: r.subtitleSize, color: onBg),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(fontSize: r.subtitleSize, color: onBg.withValues(alpha: 0.3)),
          border: InputBorder.none,
          icon: leading,
          suffixIcon: controller.text.isNotEmpty
            ? GestureDetector(onTap: onClear,
                child: Icon(Icons.clear, size: r.footerSize + 2, color: onBg.withValues(alpha: 0.3)))
            : null,
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────── Nav Buttons ─────────────────────────────────────────────────────

class TutorialNavButtons extends StatelessWidget {
  final Color glowColor;
  final bool nextOk;
  final bool saving;
  final String backLabel;
  final String continueLabel;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  const TutorialNavButtons({
    super.key,
    required this.glowColor,
    required this.nextOk,
    required this.saving,
    required this.backLabel,
    required this.continueLabel,
    required this.onBack,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
      child: SizedBox(
        height: r.continueButtonHeight,
        child: Row(children: [
          Expanded(child: GlassButton(
            label: backLabel,
            onPressed: onBack,
            height: r.continueButtonHeight, accent: glowColor)),
          SizedBox(width: r.spacingM),
          Expanded(child: GlassButton(
            label: continueLabel,
            onPressed: nextOk ? onContinue : null,
            isLoading: saving, height: r.continueButtonHeight, accent: glowColor)),
        ]),
      ),
    );
  }
}

// ────────────────────────────────────────────────── Search Results ──────────────────────────────────────────────────

class SearchResultsView extends StatelessWidget {
  final List<FeedItem> results;
  final String selectedType;
  final bool searching;
  final Set<String> likedIds;
  final Map<String, DownloadState> downloadStates;
  final ValueChanged<String> onToggleLike;
  final ValueChanged<String> onDownload;
  final void Function(BuildContext, FeedItem) onShowInfo;
  final void Function(BuildContext, FeedItem) onShowMore;
  final Color onBg;
  final Color glowColor;
  final String searchingLabel;
  final String emptyLabel;

  const SearchResultsView({
    super.key,
    required this.results,
    required this.selectedType,
    required this.searching,
    required this.likedIds,
    required this.downloadStates,
    required this.onToggleLike,
    required this.onDownload,
    required this.onShowInfo,
    required this.onShowMore,
    required this.onBg,
    required this.glowColor,
    required this.searchingLabel,
    required this.emptyLabel,
  });

  bool get _isEmpty => results.isEmpty;
  bool get _isTrackType => selectedType == 'tracks';

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return _searchingIndicator(context);
    }
    if (_isEmpty) {
      return Center(
        child: Text(emptyLabel, style: TextStyle(fontSize: Responsive(context).footerSize, color: onBg.withValues(alpha: 0.4))),
      );
    }
    if (_isTrackType) return _trackList(context);
    return _gridResults(context);
  }

  Widget _searchingIndicator(BuildContext context) {
    final r = Responsive(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: r.footerSize + 4, height: r.footerSize + 4,
          child: CircularProgressIndicator(strokeWidth: 2, color: glowColor)),
        SizedBox(height: r.spacingS),
        Text(searchingLabel, style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.4))),
      ]),
    );
  }

  Widget _trackList(BuildContext context) {
    final r = Responsive(context);
    return ListView(
      padding: EdgeInsets.all(r.spacingS),
      children: results.map((item) {
        final id = '${item.type}_${item.id}_${item.source}';
        return Padding(
          padding: EdgeInsets.only(bottom: r.spacingXS),
          child: TrackCard(
            title: item.name, subtitle: item.artists ?? '', coverUrl: item.coverUrl,
            isLiked: likedIds.contains(id), onLike: () => onToggleLike(id),
            downloadState: downloadStates[id] ?? DownloadState.none,
            onDownload: () => onDownload(id),
            onInfo: () => onShowInfo(context, item),
            onMore: () => onShowMore(context, item),
            showActions: false,
          ),
        );
      }).toList(),
    );
  }

  Widget _gridResults(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.symmetric(vertical: Responsive(context).spacingS),
    child: _gridSection(context, results),
  );

  Widget _gridSection(BuildContext context, List<FeedItem> items) {
    final r = Responsive(context);
    return LayoutBuilder(
      builder: (_, constraints) {
        final avail = constraints.maxWidth - 2 * r.spacingS;
        final crossAxisCount = avail > 700 ? 4 : avail > 340 ? 3 : 2;
        final gap = r.spacingXS;
        final cardWidth = (avail - (crossAxisCount - 1) * gap) / crossAxisCount;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: r.spacingS),
          child: Wrap(
            spacing: gap, runSpacing: r.spacingXS,
            children: items.map((item) {
              final id = '${item.type}_${item.id}_${item.source}';
              return SizedBox(
                width: cardWidth,
                child: GridCard(
                  type: item.type, title: item.name, subtitle: item.artists ?? '', coverUrl: item.coverUrl,
                  isLiked: likedIds.contains(id), onLike: () => onToggleLike(id),
                  downloadState: downloadStates[id] ?? DownloadState.none,
                  onDownload: () => onDownload(id),
                  onMore: () => onShowMore(context, item),
                  showActions: false,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}


