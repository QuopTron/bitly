import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/constants/source_constants.dart';
import '../../../shared/models/feed_models.dart';

class SearchBarWidget extends StatefulWidget {
  final TextEditingController controller;
  final String selectedSource;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onClear;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.selectedSource,
    required this.onSourceChanged,
    required this.onTextChanged,
    required this.onClear,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? Colors.white : Colors.black;
    final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;

    return GlassContainer(
      borderRadius: 14,
      borderColor: glowColor.withValues(alpha: 0.18),
      margin: EdgeInsets.fromLTRB(r.spacingS, r.spacingS, r.spacingS, 0),
      padding: EdgeInsets.symmetric(horizontal: r.spacingM),
      child: TextField(
        controller: widget.controller,
        onChanged: widget.onTextChanged,
        style: TextStyle(fontSize: r.subtitleSize + 3, color: onBg),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context).setup.searchHint,
          hintStyle: TextStyle(fontSize: r.subtitleSize + 3, color: onBg.withValues(alpha: 0.3)),
          border: InputBorder.none,
          icon: _sourceDropdown(isDark, onBg, glowColor, r),
          suffixIcon: widget.controller.text.isNotEmpty
              ? GestureDetector(onTap: widget.onClear,
                  child: Icon(Icons.clear, size: r.footerSize + 5, color: onBg.withValues(alpha: 0.3)))
              : null,
        ),
      ),
    );
  }

  Widget _sourceDropdown(bool isDark, Color onBg, Color glowColor, Responsive r) {
    return PopupMenuButton<String>(
      onSelected: widget.onSourceChanged,
      offset: const Offset(0, 40),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      constraints: BoxConstraints(maxHeight: 320, minWidth: 180),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(sourceIcons[widget.selectedSource] ?? Icons.search, size: r.footerSize + 5, color: glowColor.withValues(alpha: 0.8)),
        Icon(Icons.arrow_drop_down, size: r.footerSize + 2, color: onBg.withValues(alpha: 0.4)),
      ]),
      itemBuilder: (_) => allSources.map((src) {
        final sel = src == widget.selectedSource;
        return PopupMenuItem<String>(
          value: src, height: 40,
          child: Row(children: [
            Icon(sourceIcons[src] ?? Icons.music_video, size: r.footerSize + 2,
              color: sel ? glowColor : onBg.withValues(alpha: 0.5)),
            SizedBox(width: r.spacingXS),
            Expanded(child: Text(sourceDisplayName(src),
              style: TextStyle(fontSize: r.subtitleSize,
                color: sel ? glowColor : onBg.withValues(alpha: 0.7),
                fontWeight: sel ? FontWeight.w600 : FontWeight.normal))),
            if (sel) Icon(Icons.check, size: r.footerSize, color: glowColor),
          ]),
        );
      }).toList(),
    );
  }


}

class SearchTypeChips extends StatelessWidget {
  /// Currently active filter category (canonical), or null to show every
  /// category together.
  final String? selectedType;
  /// The category bubbles for the current source, from its manifest.
  final List<SearchFilterConfig> filters;
  final ValueChanged<String?> onTypeChanged;

  const SearchTypeChips({
    super.key,
    required this.selectedType,
    required this.filters,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? Colors.white : Colors.black;
    final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;
    final loc = AppLocalizations.of(context);

    if (filters.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingS),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: filters.map((f) {
          final cat = searchCategoryOf(f.id);
          final sel = selectedType == cat;
          return Padding(
            padding: EdgeInsets.only(right: r.spacingXS),
            child: GestureDetector(
              onTap: () => onTypeChanged(sel ? null : cat),
              child: GlassContainer(
                borderRadius: 22,
                borderColor: sel ? glowColor : onBg.withValues(alpha: 0.1),
                bgColor: sel ? glowColor.withValues(alpha: 0.16) : Colors.transparent,
                padding: EdgeInsets.symmetric(horizontal: r.spacingM + 2, vertical: r.spacingXS + 2),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(searchFilterIcon(f.icon, cat), size: r.footerSize + 3,
                    color: sel ? glowColor : onBg.withValues(alpha: 0.5)),
                  SizedBox(width: r.spacingXS),
                  Text(_typeLabel(cat, f.label, loc),
                    style: TextStyle(fontSize: r.subtitleSize,
                      color: sel ? glowColor : onBg.withValues(alpha: 0.55),
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
                ]),
              ),
            ),
          );
        }).toList()),
      ),
    );
  }

  String _typeLabel(String cat, String manifestLabel, AppLocalizations loc) {
    if (manifestLabel.isNotEmpty) return manifestLabel;
    switch (cat) {
      case 'tracks': return loc.setup.searchTracks;
      case 'artists': return loc.setup.searchArtists;
      case 'albums': return loc.setup.searchAlbums;
      case 'playlists': return loc.setup.searchPlaylists;
      default: return cat;
    }
  }
}


