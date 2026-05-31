import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/utils/clickable_metadata.dart';
import 'package:bitly/widgets/cached_cover_image.dart';
import 'package:bitly/theme/app_theme.dart';
import 'package:bitly/widgets/glass_container.dart';

enum AlbumCardLayout { grid, row }

class AlbumCard extends ConsumerWidget {
  final String albumName;
  final String artistName;
  final String? coverUrl;
  final String? coverPath;
  final int trackCount;
  final AlbumCardLayout layout;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onHeartTap;

  // Selection mode
  final bool showSelectionCheckbox;
  final bool isSelected;

  // Favorite
  final bool isFavorite;

  // Type badge (EP/Single)
  final bool showTypeBadge;
  final String? albumType;

  // Downloaded badge
  final bool showDownloadedBadge;

  // Source badge (for queue tab grid)
  final IconData? badgeIcon;
  final Color? badgeColor;
  final Color? badgeTextColor;

  // Row-specific
  final bool showDivider;
  final Widget? trailing;
  final bool showArtistAsClickable;

  // Fixed dimensions (for horizontal scroll lists)
  final double? width;
  final double? height;

  const AlbumCard({
    super.key,
    required this.albumName,
    required this.artistName,
    this.coverUrl,
    this.coverPath,
    this.trackCount = 0,
    this.layout = AlbumCardLayout.grid,
    this.onTap,
    this.onLongPress,
    this.onHeartTap,
    this.showSelectionCheckbox = false,
    this.isSelected = false,
    this.isFavorite = false,
    this.showTypeBadge = false,
    this.albumType,
    this.showDownloadedBadge = false,
    this.badgeIcon,
    this.badgeColor,
    this.badgeTextColor,
    this.showDivider = false,
    this.trailing,
    this.showArtistAsClickable = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (layout) {
      case AlbumCardLayout.grid:
        return _buildGrid(context, ref);
      case AlbumCardLayout.row:
        return _buildRow(context, ref);
    }
  }

  Widget _buildGrid(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cover = _buildCover(context, colorScheme);

    return Semantics(
      button: true,
      label: 'Open album $albumName by $artistName',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: NeonCard(
          margin: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          onTap: null,
          borderRadius: 16,
          glowColor: isSelected ? colorScheme.primary : null,
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                // Background with cover and blur
                Positioned.fill(
                  child: cover ?? _albumPlaceholder(colorScheme, isDark),
                ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          isDark 
                              ? AppTheme.bgPrimaryDark.withOpacity(0.7)
                              : AppTheme.bgPrimaryLight.withOpacity(0.7),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                ),
                
                // Album cover in the top section
                Positioned(
                  left: 8, right: 8, top: 8,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: cover ?? _albumPlaceholder(colorScheme, isDark),
                    ),
                  ),
                ),
                
                // Selection checkbox - top left
                if (showSelectionCheckbox)
                  Positioned(
                    top: 4, left: 4,
                    child: _SelectionCheckbox(
                      visible: true,
                      selected: isSelected,
                      colorScheme: colorScheme,
                      isDark: isDark,
                    ),
                  ),
                
                // Downloaded badge - top right
                if (showDownloadedBadge)
                  Positioned(
                    top: 4, right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.successDark : AppTheme.successLight,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? AppTheme.successDark.withOpacity(0.4) : AppTheme.successLight.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.download_done, 
                        size: 12, 
                        color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight
                      ),
                    ),
                  ),
                
                // Type badge - bottom left
                if (showTypeBadge && albumType != null)
                  Positioned(
                    left: 6, bottom: 40,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? AppTheme.surfaceDark.withOpacity(0.8)
                            : AppTheme.surfaceLight.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? AppTheme.glassBorderDark : AppTheme.glassBorderLight,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        albumType == 'ep' ? 'EP' : 'Single',
                        style: TextStyle(
                          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                          fontSize: 10,
                          fontWeight: FontWeight.w600
                        ),
                      ),
                    ),
                  ),
                
                // Badge icon - top right
                if (badgeIcon != null)
                  Positioned(
                    right: 4, top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: badgeColor ?? (isDark ? AppTheme.primaryDark : AppTheme.primaryLight),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? AppTheme.primaryDark.withOpacity(0.4) : AppTheme.primaryLight.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        badgeIcon,
                        size: 14,
                        color: badgeIcon == Icons.favorite 
                            ? (isDark ? Colors.redAccent : Colors.red.shade700)
                            : (badgeTextColor ?? (isDark ? Colors.black : Colors.white)),
                      ),
                    ),
                  ),
                
                // Favorite button - top right
                if (onHeartTap != null)
                  Positioned(
                    right: 4, top: 4,
                    child: GestureDetector(
                      onTap: onHeartTap,
                      behavior: HitTestBehavior.translucent,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? AppTheme.surfaceDark.withOpacity(0.7)
                              : AppTheme.surfaceLight.withOpacity(0.7),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppTheme.glassBorderDark : AppTheme.glassBorderLight,
                            width: 0.5,
                          ),
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: isFavorite 
                              ? (isDark ? Colors.redAccent : Colors.red.shade700)
                              : (isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight).withOpacity(0.7),
                        ),
                      ),
                    ),
                  ),
                
                // Album info at bottom
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: NeonCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                    borderRadius: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          albumName,
                          style: TextStyle(
                            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          artistName,
                          style: TextStyle(
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (trackCount > 0)
                          Text(
                            '$trackCount canciones',
                            style: TextStyle(
                              color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coverWidget = _buildCover(context, colorScheme, size: 56);

    return NeonCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      onTap: onTap,
      borderRadius: 16,
      child: Row(
        children: [
          // Cover with badges
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: coverWidget ?? _albumPlaceholder(colorScheme, isDark),
                ),
              ),
              if (showDownloadedBadge)
                Positioned(
                  right: 2, bottom: 2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.successDark : AppTheme.successLight,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? AppTheme.successDark.withOpacity(0.4) : AppTheme.successLight.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.download_done, size: 12, color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  albumName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                showArtistAsClickable && artistName.isNotEmpty
                    ? ClickableArtistName(
                        artistName: artistName,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : Text(
                        artistName.isNotEmpty ? artistName : 'Álbum',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ],
            ),
          ),
          if (trailing != null) 
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: trailing!,
            ),
        ],
      ),
    );
  }

  Widget? _buildCover(BuildContext context, ColorScheme colorScheme, {double? size}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (coverUrl != null && Uri.tryParse(coverUrl!)?.hasAuthority == true) {
      return CachedCoverImage(
        imageUrl: coverUrl!,
        width: size ?? double.infinity,
        height: size ?? double.infinity,
        fit: BoxFit.cover,
        memCacheWidth: size != null ? (size * 2).round() : 300,
        memCacheHeight: size != null ? (size * 2).round() : 300,
        placeholder: (_, __) => _albumPlaceholder(colorScheme, isDark),
        errorWidget: (_, __, ___) => _albumPlaceholder(colorScheme, isDark),
      );
    }
    if (coverPath != null && File(coverPath!).existsSync()) {
      return Image.file(
        File(coverPath!),
        fit: BoxFit.cover,
        width: size ?? double.infinity,
        height: size ?? double.infinity,
        cacheWidth: size != null ? (size * 2).round() : 300,
        cacheHeight: size != null ? (size * 2).round() : 300,
        errorBuilder: (_, __, ___) => _albumPlaceholder(colorScheme, isDark),
      );
    }
    return null;
  }

  Widget _albumPlaceholder(ColorScheme colorScheme, bool isDark) {
    return Container(
      color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      child: Center(
        child: Icon(
          Icons.album, 
          color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight, 
          size: 48
        ),
      ),
    );
  }
}

class _SelectionCheckbox extends StatelessWidget {
  final bool visible;
  final bool selected;
  final ColorScheme colorScheme;
  final bool isDark;

  const _SelectionCheckbox({
    required this.visible,
    required this.selected,
    required this.colorScheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected
            ? (isDark ? AppTheme.primaryDark : AppTheme.primaryLight)
            : colorScheme.surface.withValues(alpha: 0.85),
        border: Border.all(
          color: selected 
              ? (isDark ? AppTheme.primaryDark : AppTheme.primaryLight)
              : (isDark ? AppTheme.glassBorderDark : AppTheme.glassBorderLight),
          width: 1.5,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: isDark ? AppTheme.primaryDark.withOpacity(0.4) : AppTheme.primaryLight.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: selected
          ? Icon(
              Icons.check, 
              size: 16, 
              color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight
            )
          : null,
    );
  }
}
