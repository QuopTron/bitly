import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/widgets/cached_cover_image.dart';
import 'package:bitly/theme/app_theme.dart';
import 'package:bitly/widgets/glass_container.dart';

enum ArtistCardLayout { grid, row }

class ArtistCard extends ConsumerWidget {
  final String artistName;
  final String? imageUrl;
  final String? coverPath;
  final List<String> alternateCovers;
  final ArtistCardLayout layout;
  final VoidCallback? onTap;
  final VoidCallback? onHeartTap;
  final bool isFavorite;
  final bool showDivider;
  final Widget? trailing;
  final int coverIndex;

  const ArtistCard({
    super.key,
    required this.artistName,
    this.imageUrl,
    this.coverPath,
    this.alternateCovers = const [],
    this.layout = ArtistCardLayout.grid,
    this.onTap,
    this.onHeartTap,
    this.isFavorite = false,
    this.showDivider = false,
    this.trailing,
    this.coverIndex = 0,
  });

  List<String> get _allCovers {
    final urls = <String>[];
    if (imageUrl != null && imageUrl!.isNotEmpty) urls.add(imageUrl!);
    urls.addAll(alternateCovers);
    return urls.toSet().toList();
  }

  String? get _effectiveCoverUrl {
    final covers = _allCovers;
    if (covers.isEmpty) return imageUrl;
    return covers[coverIndex % covers.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (layout) {
      case ArtistCardLayout.grid:
        return _buildGrid(context);
      case ArtistCardLayout.row:
        return _buildRow(context);
    }
  }

  Widget _buildGrid(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coverUrl = _effectiveCoverUrl;

    return GestureDetector(
      onTap: onTap,
      child: NeonCard(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        onTap: null,
        borderRadius: 16,
        glowColor: isFavorite ? colorScheme.primary : null,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              // Background with cover and blur
              Positioned.fill(
                child: _buildCover(coverUrl, coverPath, colorScheme, isDark),
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
              
              // Artist avatar in center
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: isDark 
                                ? AppTheme.primaryDark.withOpacity(0.4)
                                : AppTheme.primaryLight.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          width: 90,
                          height: 90,
                          child: _buildCover(coverUrl, coverPath, colorScheme, isDark),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Artist name in glass container
                    NeonCard(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      borderRadius: 12,
                      child: Text(
                        artistName,
                        style: TextStyle(
                          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    if (_allCovers.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${coverIndex + 1}/${_allCovers.length}',
                          style: TextStyle(
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
              
              // Favorite button - top right
              if (onHeartTap != null)
                Positioned(
                  right: 6,
                  top: 6,
                  child: GestureDetector(
                    onTap: onHeartTap,
                    behavior: HitTestBehavior.translucent,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? AppTheme.surfaceDark.withOpacity(0.7)
                            : AppTheme.surfaceLight.withOpacity(0.7),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppTheme.glassBorderDark : AppTheme.glassBorderLight,
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? AppTheme.primaryDark.withOpacity(0.3) : AppTheme.primaryLight.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coverUrl = _effectiveCoverUrl;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NeonCard(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          onTap: onTap,
          borderRadius: 16,
          child: Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: _buildCover(coverUrl, coverPath, colorScheme, isDark),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  artistName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) 
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: trailing!,
                ),
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassDivider(height: 1, indent: 80, endIndent: 12),
          ),
      ],
    );
  }

  Widget _buildCover(String? url, String? path, ColorScheme colorScheme, bool isDark) {
    if (path != null && File(path).existsSync()) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _artistPlaceholder(colorScheme, isDark),
      );
    }
    if (url != null && url.isNotEmpty && Uri.tryParse(url)?.hasAuthority == true) {
      return CachedCoverImage(
        imageUrl: url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => _artistPlaceholder(colorScheme, isDark),
        errorWidget: (_, __, ___) => _artistPlaceholder(colorScheme, isDark),
      );
    }
    return _artistPlaceholder(colorScheme, isDark);
  }

  Widget _artistPlaceholder(ColorScheme colorScheme, bool isDark) {
    return Container(
      color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      child: Center(
        child: Icon(
          Icons.person, 
          size: 48, 
          color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight
        ),
      ),
    );
  }
}
