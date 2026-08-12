import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/constants/source_constants.dart';
import '../../../shared/models/feed_models.dart';

class SearchBarWidget extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onClear;
  /// Optional per-source hint (e.g. "Search Deezer..." from the manifest).
  /// When null the localized generic search hint is used.
  final String? hintText;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.onTextChanged,
    required this.onClear,
    this.hintText,
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
          hintText: widget.hintText ??
              AppLocalizations.of(context).setup.searchHint,
          hintStyle: TextStyle(fontSize: r.subtitleSize + 3, color: onBg.withValues(alpha: 0.3)),
          border: InputBorder.none,
          icon: Icon(Icons.search, size: r.footerSize + 5, color: glowColor.withValues(alpha: 0.8)),
          suffixIcon: widget.controller.text.isNotEmpty
              ? GestureDetector(onTap: widget.onClear,
                  child: Icon(Icons.clear, size: r.footerSize + 5, color: onBg.withValues(alpha: 0.3)))
              : null,
        ),
      ),
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


