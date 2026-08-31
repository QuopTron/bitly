import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../models/performance_profile.dart';
import '../../../injection.dart';
import '../../../backend/services/player_cubit.dart';
import 'cover_image.dart';
import 'download_indicator.dart';

class TrackCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? coverUrl;
  final VoidCallback? onTap;
  final bool isLiked;
  final VoidCallback? onLike;
  final DownloadState downloadState;
  final VoidCallback? onDownload;
  final VoidCallback? onPause;
  final VoidCallback? onDelete;
  final VoidCallback? onInfo;
  final VoidCallback? onMore;
  final VoidCallback? onShare;
  final VoidCallback? onEditTags;
  final bool showDeleteAnimation;
  final bool showActions;
  final bool actionsEnabled;
  final double textScale;

  /// Optional normalized track ID. When the player signals this track is ready
  /// to play instantly (stream pre-resolved or local file), a small badge is
  /// shown on the cover so the user knows it will start with zero wait.
  final String? readyKey;
  const TrackCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.coverUrl,
    this.onTap,
    this.isLiked = false,
    this.onLike,
    this.downloadState = DownloadState.none,
    this.onDownload,
    this.onPause,
    this.onDelete,
    this.onInfo,
    this.onMore,
    this.onShare,
    this.onEditTags,
    this.showDeleteAnimation = false,
    this.showActions = true,
    this.actionsEnabled = true,
    this.textScale = 1.0,
    this.readyKey,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const textColor = Colors.white;
    const mutedColor = Color(0xFFB0B0B0);
    final fallbackBg =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFD0D0D0);
    final fallbackIconColor =
        isDark ? const Color(0xFF888888) : const Color(0xFF666666);
    final iSize = r.footerSize * 1.6 * textScale;
    final ts = textScale;

    return RepaintBoundary(
      child: Container(
        width: r.width * 0.82,
        margin: EdgeInsets.symmetric(
          horizontal: r.spacingS,
          vertical: r.spacingXS,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: downloadState == DownloadState.completed
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.1),
            width: downloadState == DownloadState.completed ? 1.0 : 0.7,
          ),
          boxShadow: [
            if (heavyEffects)
              BoxShadow(
                color: downloadState == DownloadState.completed
                    ? Colors.black.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.3),
                blurRadius: 14,
                spreadRadius: 0,
                offset: const Offset(0, 5),
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (coverUrl != null && coverUrl!.isNotEmpty)
              Positioned.fill(child: imageFromUrl(coverUrl, fit: BoxFit.cover)),
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),
            if (readyKey != null && readyKey!.isNotEmpty)
              Positioned(
                top: r.spacingXS,
                left: r.spacingS,
                child: ValueListenableBuilder<Set<String>>(
                  valueListenable: sl<PlayerCubit>().readyTracks,
                  builder:
                      (context, ready, _) =>
                          ready.contains(readyKey)
                              ? Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF4CAF50,
                                    ).withValues(alpha: 0.6),
                                    width: 0.6,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.bolt,
                                      size: r.footerSize - 2,
                                      color: const Color(0xFF66BB6A),
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      loc.setup.readyBadge,
                                      style: TextStyle(
                                        fontSize: r.footerSize - 3,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF81C784),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : const SizedBox.shrink(),
                ),
              ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: isDark ? 0.05 : 0.0),
                      Colors.transparent,
                      Colors.black.withValues(alpha: heavyEffects ? 0.45 : 0.3),
                    ],
                    stops: const [0.0, 0.35, 1.0],
                  ),
                ),
              ),
            ),
            // Ripple + tap feedback: above the artwork but below the content so
            // the on-screen action buttons keep receiving their own taps.
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  customBorder: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                  ),
                  splashColor: Colors.white.withValues(alpha: 0.14),
                  highlightColor: Colors.white.withValues(alpha: 0.06),
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
                      width: r.subtitleSize * 5.5,
                      height: r.subtitleSize * 5.5,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: coverUrl == null ? fallbackBg : null,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 0.5,
                        ),
                        boxShadow:
                            heavyEffects
                                ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                                : null,
                      ),
                      child:
                          coverUrl != null
                              ? imageFromUrl(
                                coverUrl,
                                fit: BoxFit.cover,
                                fallback: Icon(
                                  Icons.music_note,
                                  color: fallbackIconColor,
                                  size: 34,
                                ),
                              )
                              : Icon(
                                Icons.music_note,
                                color: fallbackIconColor,
                                size: 34,
                              ),
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
                          style: TextStyle(
                            fontSize: r.subtitleSize * ts,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: (r.footerSize - 1) * ts,
                            color: mutedColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (showActions)
                    _actionCluster(
                      context,
                      r,
                      loc,
                      iSize,
                      mutedColor,
                      textColor,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCluster(
    BuildContext context,
    Responsive r,
    AppLocalizations loc,
    double iSize,
    Color mutedColor,
    Color textColor,
  ) {
    Widget cluster = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DownloadIndicator(
          state: showDeleteAnimation ? DownloadState.completed : downloadState,
          size: 10,
        ),
        SizedBox(width: r.spacingS),
        Semantics(
          button: true,
          label: isLiked ? loc.setup.a11yUnlike : loc.setup.a11yLike,
          child: GestureDetector(
            onTap: onLike,
            child: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.red : Colors.white.withValues(alpha: 0.6),
              size: iSize,
            ),
          ),
        ),
        SizedBox(width: r.spacingXS),
        // Download action: gray dot → ⬇️, orange → ⏸️, green → 🗑️, red → 🔄
        Tooltip(
          message: _trackDownloadTooltip(loc),
          child: GestureDetector(
            onTap: _trackDownloadAction,
            child: Icon(
              _trackDownloadIcon,
              size: iSize,
              color: _trackDownloadIconColor,
            ),
          ),
        ),
        SizedBox(width: r.spacingXS),
        Semantics(
          button: true,
          label: loc.setup.a11yShare,
          child: GestureDetector(
            onTap: onShare,
            child: Icon(Icons.share, size: iSize, color: mutedColor),
          ),
        ),
        SizedBox(width: r.spacingXS),
        Semantics(
          button: true,
          label: loc.setup.a11yInfo,
          child: GestureDetector(
            onTap: onInfo,
            child: Icon(Icons.info_outline, size: iSize, color: mutedColor),
          ),
        ),
        SizedBox(width: r.spacingXS),
        Semantics(
          button: true,
          label: loc.setup.a11yMore,
          child: GestureDetector(
            onTap: onMore,
            child: Icon(
              Icons.more_horiz,
              size: iSize + 2,
              color: textColor.withValues(alpha: 0.5),
            ),
          ),
        ),
        if (onEditTags != null) ...[
          SizedBox(width: r.spacingXS),
          Semantics(
            button: true,
            label: 'Edit tags',
            child: GestureDetector(
              onTap: onEditTags,
              child: Icon(Icons.edit, size: iSize, color: mutedColor),
            ),
          ),
        ],
      ],
    );

    if (actionsEnabled) return cluster;
    return IgnorePointer(child: Opacity(opacity: 0.4, child: cluster));
  }

  // ── Download state helpers ──

  String _trackDownloadTooltip(AppLocalizations loc) {
    final ds = showDeleteAnimation ? DownloadState.completed : downloadState;
    switch (ds) {
      case DownloadState.interrupted:
        return loc.setup.downloadTooltipRetry;
      case DownloadState.inProgress:
        return 'Pausar descarga';
      case DownloadState.completed:
        return loc.setup.downloadTooltipDelete;
      default:
        return loc.setup.downloadTooltipDownload;
    }
  }

  VoidCallback? get _trackDownloadAction {
    final ds = showDeleteAnimation ? DownloadState.completed : downloadState;
    switch (ds) {
      case DownloadState.inProgress:
        return onPause ?? onDelete;
      case DownloadState.completed:
        return onDelete ?? onDownload;
      case DownloadState.interrupted:
        return onDownload; // retry
      default:
        return onDownload;
    }
  }

  IconData get _trackDownloadIcon {
    final ds = showDeleteAnimation ? DownloadState.completed : downloadState;
    switch (ds) {
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

  Color get _trackDownloadIconColor {
    final ds = showDeleteAnimation ? DownloadState.completed : downloadState;
    switch (ds) {
      case DownloadState.inProgress:
        return const Color(0xFFFF9800); // orange
      case DownloadState.completed:
        return Colors.red.withValues(alpha: 0.6);
      case DownloadState.interrupted:
        return const Color(0xFFE53935);
      default:
        return Colors.white.withValues(alpha: 0.5);
    }
  }

  // Static helpers removed — use isLocalUrl/imageFromUrl from cover_image.dart instead.
}
