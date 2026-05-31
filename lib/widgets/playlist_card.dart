import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/widgets/cached_cover_image.dart';
import 'package:bitly/theme/app_theme.dart';
import 'package:bitly/widgets/glass_container.dart';

enum PlaylistCardLayout { grid, row }

class PlaylistCard extends ConsumerWidget {
  final String playlistName;
  final String? coverUrl;
  final String? coverPath;
  final String? subtitle;
  final int trackCount;
  final PlaylistCardLayout layout;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onHeartTap;
  final bool isFavorite;
  final bool showDivider;
  final Widget? trailing;
  final double? width;
  final double? height;

  const PlaylistCard({
    super.key,
    required this.playlistName,
    this.coverUrl,
    this.coverPath,
    this.subtitle,
    this.trackCount = 0,
    this.layout = PlaylistCardLayout.grid,
    this.onTap,
    this.onLongPress,
    this.onHeartTap,
    this.isFavorite = false,
    this.showDivider = false,
    this.trailing,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (layout) {
      case PlaylistCardLayout.grid:
        return _buildGrid(context);
      case PlaylistCardLayout.row:
        return _buildRow(context);
    }
  }

  Widget _buildGrid(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cover = _buildCover(colorScheme, isDark);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: NeonCard(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        onTap: null,
        borderRadius: 16,
        glowColor: isFavorite ? colorScheme.primary : null,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              // Background with cover and blur
              Positioned.fill(
                child: cover,
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
              
              // Playlist cover in top section
              Positioned(
                left: 8, right: 8, top: 8,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: cover,
                  ),
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
              
              // Playlist info at bottom
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
                        playlistName,
                        style: TextStyle(
                          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null || trackCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle ?? '$trackCount canciones',
                            style: TextStyle(
                              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
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
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: _buildCover(colorScheme, isDark),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      playlistName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null || trackCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle ?? '$trackCount canciones',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassDivider(height: 1, indent: 80, endIndent: 12),
          ),
      ],
    );
  }

  Widget _buildCover(ColorScheme colorScheme, bool isDark) {
    if (coverPath != null && File(coverPath!).existsSync()) {
      return Image.file(
        File(coverPath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _playlistPlaceholder(isDark),
      );
    }
    if (coverUrl != null && coverUrl!.isNotEmpty && Uri.tryParse(coverUrl!)?.hasAuthority == true) {
      return CachedCoverImage(
        imageUrl: coverUrl!,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => _playlistPlaceholder(isDark),
        errorWidget: (_, __, ___) => _playlistPlaceholder(isDark),
      );
    }
    return _playlistPlaceholder(isDark);
  }

  Widget _playlistPlaceholder(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDark ? Colors.purple[700]! : Colors.purple.shade300,
            isDark ? Colors.deepPurple[900]! : Colors.deepPurple.shade400,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.playlist_play, 
          color: Colors.white, 
          size: 48,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
      ),
    );
  }
}
