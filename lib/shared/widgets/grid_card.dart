import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../core/helpers/responsive.dart';
import 'download_indicator.dart';

class GridCard extends StatelessWidget {
  final String type;
  final String title;
  final String subtitle;
  final String? coverUrl;
  final VoidCallback? onTap;
  final bool isLiked;
  final VoidCallback? onLike;
  final DownloadState downloadState;
  final double downloadProgress;
  final VoidCallback? onDownload;
  final VoidCallback? onMore;
  final bool showDeleteAnimation;

  const GridCard({
    super.key,
    required this.type,
    required this.title,
    required this.subtitle,
    this.coverUrl,
    this.onTap,
    this.isLiked = false,
    this.onLike,
    this.downloadState = DownloadState.none,
    this.downloadProgress = 0.0,
    this.onDownload,
    this.onMore,
    this.showDeleteAnimation = false,
  });

  IconData get _icon {
    switch (type) {
      case 'album':
        return Icons.album;
      case 'playlist':
        return Icons.queue_music;
      case 'artist':
        return Icons.person;
      default:
        return Icons.music_note;
    }
  }

  bool get _isArtist => type == 'artist';

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const textColor = Colors.white;
    const mutedColor = Color(0xFFB0B0B0);
    final fallbackBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);

    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth;
          final imgSize = cardWidth * 0.7;

          return Container(
            width: cardWidth,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
              color: coverUrl == null ? fallbackBg : null,
            ),
        child: Stack(
          alignment: Alignment.center,
          children: [
                if (coverUrl != null)
                  Positioned.fill(
                    child: Image.network(coverUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                  ),
                if (coverUrl != null)
                  Positioned.fill(
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),
                if (coverUrl != null)
                  Positioned.fill(
                    child: Container(color: Colors.black.withValues(alpha: 0.3)),
                  ),
                // Content sizes the Stack naturally (no fixed height)
                Padding(
                  padding: EdgeInsets.all(r.spacingS),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: imgSize,
                        height: imgSize,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          shape: _isArtist ? BoxShape.circle : BoxShape.rectangle,
                          borderRadius: _isArtist ? null : BorderRadius.circular(12),
                          color: coverUrl == null ? fallbackBg : null,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: coverUrl != null
                            ? Image.network(coverUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholderIcon(imgSize))
                            : _placeholderIcon(imgSize),
                      ),
                      SizedBox(height: 4),
                      Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                        if (!_isArtist)
                          GestureDetector(
                            onTap: onDownload,
                            child: DownloadIndicator(
                              state: showDeleteAnimation ? DownloadState.completed : downloadState,
                              progress: showDeleteAnimation ? 1.0 : downloadProgress,
                              size: 10,
                            ),
                          ),
                        if (!_isArtist) SizedBox(width: r.spacingM),
                        GestureDetector(
                          onTap: onLike,
                          child: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : Colors.white.withValues(alpha: 0.75),
                            size: r.footerSize,
                          ),
                        ),
                        if (!_isArtist) SizedBox(width: r.spacingM),
                        if (!_isArtist)
                          GestureDetector(
                            onTap: onDownload,
                            child: Icon(
                              showDeleteAnimation ? Icons.delete_outline : Icons.download,
                              size: r.footerSize,
                              color: showDeleteAnimation ? Colors.red.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        SizedBox(width: r.spacingM),
                        GestureDetector(
                          onTap: onMore,
                          child: Icon(Icons.more_horiz, size: r.footerSize + 2, color: Colors.white.withValues(alpha: 0.5)),
                        ),
                      ]),
                      SizedBox(height: r.spacingXS),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: r.footerSize + 1,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: r.footerSize - 1,
                          color: mutedColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _placeholderIcon(double size) {
    return Icon(_icon, size: size * 0.25, color: Colors.white.withValues(alpha: 0.2));
  }
}
