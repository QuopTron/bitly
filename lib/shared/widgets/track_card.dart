import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../core/helpers/responsive.dart';
import '../../core/localization/app_localizations.dart';
import 'download_indicator.dart';

class TrackCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? coverUrl;
  final VoidCallback? onTap;
  final bool isLiked;
  final VoidCallback? onLike;
  final DownloadState downloadState;
  final double downloadProgress;
  final VoidCallback? onDownload;
  final VoidCallback? onInfo;
  final VoidCallback? onMore;
  final bool showDeleteAnimation;

  const TrackCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.coverUrl,
    this.onTap,
    this.isLiked = false,
    this.onLike,
    this.downloadState = DownloadState.none,
    this.downloadProgress = 0.0,
    this.onDownload,
    this.onInfo,
    this.onMore,
    this.showDeleteAnimation = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const textColor = Colors.white;
    const mutedColor = Color(0xFFB0B0B0);
    final fallbackBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFD0D0D0);
    final fallbackIconColor = isDark ? const Color(0xFF888888) : const Color(0xFF666666);
    final iSize = r.footerSize * 1.05;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: r.width * 0.82,
        margin: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: r.spacingXS),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.6),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (coverUrl != null)
              Positioned.fill(
                child: Image.network(coverUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
              ),
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(r.spacingS),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: r.subtitleSize * 4,
                      height: r.subtitleSize * 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: coverUrl == null ? fallbackBg : null,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: coverUrl != null
                          ? Image.network(coverUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(Icons.music_note, color: fallbackIconColor, size: 28))
                          : Icon(Icons.music_note, color: fallbackIconColor, size: 28),
                    ),
                  ),
                  SizedBox(width: r.spacingS),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w600, color: textColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: r.footerSize - 1, color: mutedColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: r.spacingS),
                  DownloadIndicator(
                    state: showDeleteAnimation ? DownloadState.completed : downloadState,
                    progress: showDeleteAnimation ? 1.0 : downloadProgress,
                    size: iSize + 4,
                  ),
                  SizedBox(width: r.spacingS),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: 3),
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      loc.setup.hifi,
                      style: TextStyle(
                        fontSize: iSize - 1,
                        fontWeight: FontWeight.w700,
                        color: textColor.withValues(alpha: 0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  SizedBox(width: r.spacingXS),
                  GestureDetector(
                    onTap: onLike,
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.white.withValues(alpha: 0.6),
                      size: iSize,
                    ),
                  ),
                  SizedBox(width: r.spacingXS),
                  GestureDetector(
                    onTap: onDownload,
                    child: Icon(
                      showDeleteAnimation ? Icons.delete_outline : Icons.download,
                      size: iSize,
                      color: showDeleteAnimation ? Colors.red.withValues(alpha: 0.6) : textColor.withValues(alpha: 0.5),
                    ),
                  ),
                  SizedBox(width: r.spacingXS),
                  GestureDetector(
                    onTap: onInfo,
                    child: Icon(Icons.info_outline, size: iSize, color: mutedColor),
                  ),
                  SizedBox(width: r.spacingXS),
                  GestureDetector(
                    onTap: onMore,
                    child: Icon(Icons.more_horiz, size: iSize + 2, color: textColor.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
