import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../models/performance_profile.dart';
import 'cover_image.dart';
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
  final VoidCallback? onDownload;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;
  final VoidCallback? onMore;
  final VoidCallback? onExport;
  final bool showDeleteAnimation;
  final bool showActions;
  final bool actionsEnabled;
  final double textScale;

  /// Optional badge rendered on the cover's top-left corner (e.g. an origin
  /// indicator for liked/downloaded/own items in "Mi Espacio").
  final Widget? cornerBadge;

  /// Whether the trailing (export / more) action is shown. Set false in
  /// "Mi Espacio" so album/playlist cards only expose like + download.
  final bool showThirdAction;

  /// Whether the download action is shown. Set false when an item can't be
  /// downloaded (e.g. an own/local playlist with no provider source) so the
  /// card doesn't render a dead download button.
  final bool showDownloadAction;

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
    this.onDownload,
    this.onRetry,
    this.onDelete,
    this.onMore,
    this.onExport,
    this.showDeleteAnimation = false,
    this.showActions = true,
    this.actionsEnabled = true,
    this.textScale = 1.0,
    this.cornerBadge,
    this.showThirdAction = true,
    this.showDownloadAction = true,
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

  /// Height guaranteed for the info block (actions + title + subtitle) so text
  /// and icons are ALWAYS visible regardless of the cover size.
  double _infoHeight(Responsive r, double ts, bool showActions) {
    var h = r.spacingS; // gap below cover
    if (showActions) {
      h += r.footerSize * 1.3 + r.spacingXS;
    }
    h += (r.footerSize + 4) * ts * 2 * 1.18; // title (up to 2 lines)
    h += 3 + (r.footerSize + 1) * ts * 1.18; // subtitle (1 line)
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fallbackBg =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
    final ts = textScale;

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final pad = r.spacingS;
          // Reserve the info block FIRST so text/icons are always readable,
          // then give the cover whatever vertical space is left. Never the
          // other way around (that's what squashed covers + hidden text).
          final wrapW = w - 2 * pad;
          final infoH = _infoHeight(r, ts, showActions);
          final coverSide =
              math.min(wrapW, math.max(40.0, h - infoH - pad)).toDouble();
          final hasCoverSpace = coverSide >= 40;

          return GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.translucent,
            child: Container(
            width: w,
            height: h.isFinite ? h : w + infoH + pad,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: downloadState == DownloadState.completed
                    ? AppColors.greenBright.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.1),
                width: downloadState == DownloadState.completed ? 1.2 : 0.6,
              ),
              boxShadow: downloadState == DownloadState.completed
                  ? [
                      BoxShadow(
                        color: _glowColor(context).withValues(alpha: 0.25),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
              color: fallbackBg,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Blurred cover fills the whole card as background.
                Positioned.fill(
                  child:
                      coverUrl != null && coverUrl!.isNotEmpty
                          ? ImageFiltered(
                            imageFilter:
                                heavyEffects
                                    ? ImageFilter.blur(sigmaX: 24, sigmaY: 24)
                                    : ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: imageFromUrl(coverUrl, fit: BoxFit.cover),
                          )
                          : Container(
                            decoration: BoxDecoration(
                              gradient: _placeholderGradient(context),
                            ),
                          ),
                ),
                // Scrim so foreground stays readable over any artwork.
                Positioned.fill(
                  child: Container(color: Colors.black.withValues(alpha: 0.35)),
                ),
                // Bottom-up gradient so the info block always stays legible.
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.95),
                          Colors.black.withValues(alpha: 0.5),
                          Colors.black.withValues(alpha: 0.1),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.35, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),
                // Foreground: sharp cover + info block below it.
                Padding(
                  padding: EdgeInsets.all(pad),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (hasCoverSpace)
                        Container(
                          width: coverSide,
                          height: coverSide,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            shape:
                                _isArtist
                                    ? BoxShape.circle
                                    : BoxShape.rectangle,
                            borderRadius:
                                _isArtist ? null : BorderRadius.circular(14),
                            color: coverUrl == null ? fallbackBg : null,
                            border: Border.all(
                              color:
                                  isDark
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : Colors.black.withValues(alpha: 0.1),
                              width: 0.6,
                            ),
                            boxShadow:
                                heavyEffects
                                    ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.45,
                                        ),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ]
                                    : null,
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (coverUrl != null && coverUrl!.isNotEmpty)
                                imageFromUrl(
                                  coverUrl,
                                  fit: BoxFit.cover,
                                  fallback: _placeholderIcon(
                                    coverSide,
                                    context,
                                  ),
                                )
                              else
                                _placeholderIcon(coverSide, context),
                              // Download state is shown via the action row icons —
                              // no redundant dot on the cover.
                              if (cornerBadge != null)
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: cornerBadge!,
                                ),
                            ],
                          ),
                        ),
                      if (hasCoverSpace) SizedBox(height: r.spacingS),
                      // Info block: fully visible, never clipped. Flexible so it
                      // shrinks within the card instead of overflowing when the
                      // rendered text is taller than the height estimate.
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            key: ValueKey('info_$type'),
                            physics: const NeverScrollableScrollPhysics(),
                            child: _infoBlock(context, r, ts),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
          );
        },
      ),
    );
  }

  Widget _infoBlock(BuildContext context, Responsive r, double ts) {
    const textColor = Colors.white;
    const mutedColor = Color(0xFFB0B0B0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showActions) _actionRow(context, r),
        SizedBox(height: r.spacingXS),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: (r.footerSize + 5) * ts,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: textColor,
            shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: (r.footerSize) * ts,
            fontWeight: FontWeight.w400,
            color: mutedColor,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _actionRow(BuildContext context, Responsive r) {
    final loc = AppLocalizations.of(context);
    final iconSize = r.footerSize * 1.4;
    Widget row = Wrap(
      alignment: WrapAlignment.center,
      spacing: r.spacingM * 0.6,
      runSpacing: 2,
      children: <Widget>[
        Semantics(
          button: true,
          label: isLiked ? loc.setup.a11yUnlike : loc.setup.a11yLike,
          child: GestureDetector(
            onTap: onLike,
            child: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.red : Colors.white.withValues(alpha: 0.8),
              size: iconSize,
            ),
          ),
        ),
        if (!_isArtist && showDownloadAction)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DownloadIndicator(
                state: downloadState,
                size: 8,
              ),
              SizedBox(width: 4),
              Tooltip(
                message:
                    downloadState == DownloadState.interrupted
                        ? loc.setup.downloadTooltipRetry
                        : downloadState == DownloadState.inProgress
                        ? loc.setup.downloadTooltipInProgress
                        : loc.setup.downloadTooltipDownload,
                child: GestureDetector(
                  onTap: onDownload,
                  child: Icon(
                    downloadState == DownloadState.inProgress
                        ? Icons.hourglass_top_rounded
                        : Icons.download,
                    size: iconSize,
                    color:
                        downloadState == DownloadState.inProgress
                            ? AppColors.greenBright.withValues(alpha: 0.8)
                            : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        if (showThirdAction)
          Semantics(
            button: true,
            label: loc.setup.a11yMore,
            child: GestureDetector(
              onTap: onMore,
              child: Icon(
                Icons.more_horiz,
                size: iconSize + 2,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
      ],
    );

    if (actionsEnabled) return row;
    return IgnorePointer(child: Opacity(opacity: 0.4, child: row));
  }

  LinearGradient _placeholderGradient(BuildContext context) {
    final c = _glowColor(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        c.withValues(alpha: 0.22),
        c.withValues(alpha: 0.05),
        const Color(0xFF1A1A1A),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  Color _glowColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.greenBright : AppColors.greenMedium;
  }

  Widget _placeholderIcon(double size, BuildContext context) {
    final c = _glowColor(context);
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          colors: [
            c.withValues(alpha: 0.35),
            c.withValues(alpha: 0.10),
            c.withValues(alpha: 0.02),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        padding: EdgeInsets.all(size * 0.12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: c.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: Icon(
          _icon,
          size: size * 0.42,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
