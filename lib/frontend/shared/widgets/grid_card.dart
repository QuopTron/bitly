import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../utils/haptic.dart';
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
  final double? downloadProgress;
  final VoidCallback? onDownload;
  final VoidCallback? onPause;
  final VoidCallback? onDelete;
  final VoidCallback? onRetry;
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
    this.downloadProgress,
    this.onDownload,
    this.onPause,
    this.onDelete,
    this.onRetry,
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
    final fallbackBg = AppColors.surface(isDark);
    final fg = AppColors.onSurface(isDark);
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
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: downloadState == DownloadState.completed
                    ? fg.withValues(alpha: 0.2)
                    : AppColors.borderSubtle(isDark),
                width: downloadState == DownloadState.completed ? 1.0 : 0.6,
              ),
              boxShadow: downloadState == DownloadState.completed
                  ? [
                      BoxShadow(
                        color: AppColors.shadow(isDark),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
              color: fallbackBg,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Blurred cover fills the whole card as background.
                // On low-perf devices, skip the GPU-heavy blur entirely and
                // just show a dark overlay. On high-perf, decode at low res
                // (blur masks detail anyway) to halve memory usage.
                Positioned.fill(
                  child:
                      coverUrl != null && coverUrl!.isNotEmpty
                          ? heavyEffects
                              ? ImageFiltered(
                                  imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                                  child: imageFromUrl(coverUrl, fit: BoxFit.cover,
                                      width: 128, height: 128),
                                )
                              : Container(color: fallbackBg)
                          : Container(
                            decoration: BoxDecoration(
                              gradient: _placeholderGradient(context),
                            ),
                          ),
                ),
                // Scrim so foreground stays readable over any artwork.
                Positioned.fill(
                  child: Container(color: AppColors.scrim(isDark).withValues(alpha: 0.35)),
                ),
                // Bottom-up gradient so the info block always stays legible.
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppColors.scrim(isDark).withValues(alpha: 0.95),
                          AppColors.scrim(isDark).withValues(alpha: 0.5),
                          AppColors.scrim(isDark).withValues(alpha: 0.1),
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
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(
                            shape:
                                _isArtist
                                    ? BoxShape.circle
                                    : BoxShape.rectangle,
                            borderRadius:
                                _isArtist ? null : BorderRadius.circular(14),
                            color: coverUrl == null ? fallbackBg : null,
                            border: Border.all(
                              color: AppColors.border(isDark),
                              width: 0.6,
                            ),
                            boxShadow:
                                heavyEffects
                                    ? [
                                      BoxShadow(
                                        color: AppColors.shadow(isDark).withValues(alpha: 0.45),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppColors.onSurface(isDark);
    final mutedColor = AppColors.onSurfaceMuted(isDark);
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
            shadows: [Shadow(color: AppColors.shadow(isDark), blurRadius: 8)],
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
            shadows: [Shadow(color: AppColors.shadow(isDark), blurRadius: 4)],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _actionRow(BuildContext context, Responsive r) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = AppColors.onSurface(isDark);
    final iconSize = r.footerSize * 1.8;
    Widget row = Wrap(
      alignment: WrapAlignment.center,
      spacing: r.spacingM * 0.6,
      runSpacing: 2,
      children: <Widget>[
        Semantics(
          button: true,
          label: isLiked ? loc.setup.a11yUnlike : loc.setup.a11yLike,
          child: GestureDetector(
            onTap: () { Haptic.medium(); onLike?.call(); },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: child,
              ),
              child: Icon(
                isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                key: ValueKey(isLiked),
                color: isLiked ? AppColors.error : fg.withValues(alpha: 0.8),
                size: iconSize,
              ),
            ),
          ),
        ),
        if (!_isArtist && showDownloadAction)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DownloadIndicator(
                state: downloadState,
                size: 10,
                progress: downloadProgress,
              ),
              SizedBox(width: 4),
              // Download action: gray dot → ⬇️, orange → ⏸️, green → 🗑️, red → 🔄
              Tooltip(
                message: _downloadTooltip(loc),
                child: GestureDetector(
                  onTap: _downloadAction,
                  child: Icon(
                    _downloadIcon,
                    size: iconSize,
                    color: _downloadIconColor(isDark),
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
                color: fg.withValues(alpha: 0.6),
              ),
            ),
          ),
      ],
    );

    if (actionsEnabled) return row;
    return IgnorePointer(child: Opacity(opacity: 0.4, child: row));
  }

  // ── Download state helpers ──

  String _downloadTooltip(AppLocalizations loc) {
    switch (downloadState) {
      case DownloadState.interrupted:
        return loc.setup.downloadTooltipRetry;
      case DownloadState.inProgress:
        return loc.setup.downloadTooltipPause;
      case DownloadState.completed:
        return loc.setup.downloadTooltipDelete;
      default:
        return loc.setup.downloadTooltipDownload;
    }
  }

  VoidCallback? get _downloadAction {
    switch (downloadState) {
      case DownloadState.inProgress:
        return onPause ?? onDelete;
      case DownloadState.completed:
        return onDelete ?? onDownload;
      case DownloadState.interrupted:
        return onRetry ?? onDownload;
      default:
        return onDownload;
    }
  }

  IconData get _downloadIcon {
    switch (downloadState) {
      case DownloadState.inProgress:
        return Icons.pause_circle_filled;
      case DownloadState.completed:
        return Icons.delete_outline;
      case DownloadState.interrupted:
        return Icons.refresh;
      default:
        return Icons.download;
    }
  }

  Color _downloadIconColor(bool isDark) {
    final fg = AppColors.onSurface(isDark);
    switch (downloadState) {
      case DownloadState.inProgress:
        return AppColors.warning;
      case DownloadState.completed:
        return AppColors.error.withValues(alpha: 0.6);
      case DownloadState.interrupted:
        return AppColors.error;
      default:
        return fg.withValues(alpha: 0.6);
    }
  }

  LinearGradient _placeholderGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = AppColors.onSurface(isDark);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        c.withValues(alpha: 0.08),
        c.withValues(alpha: 0.02),
        AppColors.surface(isDark),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  Color _glowColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppColors.onSurface(isDark);
  }

  Widget _placeholderIcon(double size, BuildContext context) {
    final c = _glowColor(context);
    return Container(
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.05),
      ),
      alignment: Alignment.center,
      child: Container(
        padding: EdgeInsets.all(size * 0.12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: c.withValues(alpha: 0.15),
            width: 1.2,
          ),
        ),
        child: Icon(
          _icon,
          size: size * 0.42,
          color: c.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
