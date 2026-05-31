import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/providers/audio_player_provider.dart';
import 'package:bitly/providers/lyrics_provider.dart';
import 'package:bitly/utils/source_icons.dart';
import 'package:bitly/widgets/audio_quality_badges.dart';
import 'package:bitly/widgets/cached_cover_image.dart';
import 'package:bitly/widgets/track_collection_quick_actions.dart';
import 'package:bitly/widgets/track_heart_button.dart';
import 'package:bitly/widgets/track_info_sheet.dart';
import 'package:bitly/theme/app_theme.dart';
import 'package:bitly/widgets/glass_container.dart';

class TrackCard extends ConsumerWidget {
  final Track track;
  final String? albumCoverUrl;
  final String? heroTag;
  final double coverSize;
  final bool showCover;
  final bool showHeartButton;
  final bool showInfoButton;
  final bool showQualityBadge;
  final bool showExplicitBadge;
  final bool showStatusLabel;
  final bool showStatusDot;
  final bool showSelectionCheckbox;
  final bool isSelected;
  final bool isCurrentTrack;
  final double downloadProgress;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;
  final ValueChanged<bool>? onToggleSelect;
  final VoidCallback? onStatusTap;
  final Widget? trailing;
  final String? statusService;

  const TrackCard({
    super.key,
    required this.track,
    this.albumCoverUrl,
    this.heroTag,
    this.coverSize = 48,
    this.showCover = true,
    this.showHeartButton = true,
    this.showInfoButton = true,
    this.showQualityBadge = true,
    this.showExplicitBadge = false,
    this.showStatusLabel = true,
    this.showStatusDot = true,
    this.showSelectionCheckbox = false,
    this.isSelected = false,
    this.isCurrentTrack = false,
    this.downloadProgress = 0.0,
    this.onTap,
    this.onDownload,
    this.onToggleSelect,
    this.onStatusTap,
    this.trailing,
    this.statusService,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coverUrl = albumCoverUrl ?? track.coverUrl;

    return NeonCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      onTap: onTap ?? () => _playTrack(context, ref),
      borderRadius: 16,
      glowColor: isCurrentTrack ? colorScheme.primary : null,
      child: Row(
        children: [
          if (showSelectionCheckbox)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _SelectionCheckbox(
                isSelected: isSelected,
                onChanged: onToggleSelect,
                context: context,
              ),
            ),
          if (showCover && coverUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _buildCover(coverUrl, colorScheme, isDark),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  track.name,
                  style: TextStyle(
                    fontWeight: isCurrentTrack ? FontWeight.bold : FontWeight.w600,
                    fontSize: 15,
                    color: isCurrentTrack 
                        ? (isDark ? AppTheme.primaryDark : AppTheme.primaryLight)
                        : colorScheme.onSurface,
                    shadows: isCurrentTrack
                        ? [
                            Shadow(
                              color: isDark 
                                  ? AppTheme.primaryDark.withOpacity(0.3)
                                  : AppTheme.primaryLight.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                _buildSubtitle(context, colorScheme, isDark),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildTrailing(context, ref, colorScheme, isDark),
        ],
      ),
    );
  }

  Widget _buildCover(String coverUrl, ColorScheme colorScheme, bool isDark) {
    final Widget child;
    if (coverUrl.startsWith('http://') || coverUrl.startsWith('https://')) {
      child = CachedCoverImage(
        imageUrl: coverUrl,
        width: coverSize,
        height: coverSize,
        borderRadius: BorderRadius.circular(10),
      );
    } else {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(coverUrl),
          width: coverSize,
          height: coverSize,
          fit: BoxFit.cover,
          errorBuilder: (_, _,__) => Container(
            width: coverSize,
            height: coverSize,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark.withOpacity(0.3) : AppTheme.surfaceLight.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.music_note, color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    if (heroTag != null) {
      return Hero(tag: heroTag!, child: child);
    }
    return child;
  }

  Widget _buildSubtitle(BuildContext context, ColorScheme colorScheme, bool isDark) {
    final parts = <InlineSpan>[];
    parts.add(TextSpan(
      text: track.artistName,
      style: TextStyle(
        fontSize: 13,
        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
      ),
    ));
    if (track.albumName.isNotEmpty) {
      final sep = track.isSingle ? ' — ' : ' · ';
      parts.add(TextSpan(
        text: '$sep${track.albumName}',
        style: TextStyle(
          fontSize: 12,
          color: (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight).withValues(alpha: 0.7),
        ),
      ));
    }
    if (track.codec != null && track.codec!.isNotEmpty) {
      parts.add(TextSpan(
        text: ' · ',
        style: TextStyle(
          fontSize: 12,
          color: (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight).withValues(alpha: 0.5),
        ),
      ));
      parts.add(TextSpan(
        text: track.codec!.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: (isDark ? AppTheme.primaryDark : AppTheme.primaryLight).withValues(alpha: 0.7),
        ),
      ));
    }
    return RichText(
      text: TextSpan(children: parts),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTrailing(BuildContext context, WidgetRef ref, ColorScheme colorScheme, bool isDark) {
    final children = <Widget>[];

    if (showExplicitBadge) {
      children.add(_Badge(label: 'E', color: colorScheme.error, context: context, isDark: isDark));
      children.add(const SizedBox(width: 4));
    }

    if (showQualityBadge && (track.audioQuality != null || (track.codec != null && track.codec!.isNotEmpty))) {
      children.addAll(buildQualityBadges(
        audioQuality: track.audioQuality,
        audioModes: track.audioModes,
        colorScheme: colorScheme,
        codec: track.codec,
      ));
      children.add(const SizedBox(width: 4));
    }

    if (showStatusLabel) {
      final isLocal = downloadProgress >= 1.0;
      final label = isLocal ? 'Local' : 'En línea';
      children.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isLocal
                ? (isDark ? AppTheme.successDark.withOpacity(0.12) : AppTheme.successLight.withOpacity(0.12))
                : (isDark ? AppTheme.textSecondaryDark.withOpacity(0.08) : AppTheme.textSecondaryLight.withOpacity(0.08)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isLocal
                  ? (isDark ? AppTheme.successDark.withOpacity(0.2) : AppTheme.successLight.withOpacity(0.2))
                  : (isDark ? AppTheme.borderDark.withOpacity(0.3) : AppTheme.borderLight.withOpacity(0.3)),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLocal ? Icons.folder_rounded : Icons.cloud_outlined,
                size: 10,
                color: isLocal 
                    ? (isDark ? AppTheme.successDark : AppTheme.successLight)
                    : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
              ),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isLocal 
                      ? (isDark ? AppTheme.successDark : AppTheme.successLight)
                      : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                  height: 1.3,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      );
      children.add(const SizedBox(width: 4));
    }

    if (showStatusDot) {
      final isDownloading = downloadProgress > 0 && downloadProgress < 1.0;
      Widget statusWidget;
      if (isDownloading && statusService != null) {
        statusWidget = _DownloadProgressPill(
          progress: downloadProgress,
          service: statusService!,
          colorScheme: colorScheme,
          context: context,
          isDark: isDark,
        );
      } else {
        statusWidget = _StatusDot(progress: downloadProgress, size: 12, context: context, isDark: isDark);
      }
      children.add(
        GestureDetector(
          onTap: onStatusTap,
          child: statusWidget,
        ),
      );
      children.add(const SizedBox(width: 4));
    }

    if (showHeartButton) {
      children.add(
        SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: TrackHeartButton(track: track),
          ),
        ),
      );
    }

    if (showInfoButton) {
      children.add(
        SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: IconButton(
              icon: Icon(Icons.info_outline, size: 18, color: colorScheme.onSurfaceVariant),
              onPressed: () => showTrackInfoSheet(context, track),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ),
        ),
      );
    }

    if (onDownload != null) {
      children.add(
        SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: IconButton(
              icon: Icon(Icons.download, size: 18, color: colorScheme.onSurfaceVariant),
              onPressed: onDownload,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ),
        ),
      );
    }

    children.add(TrackCollectionQuickActions(track: track));

    if (trailing != null) {
      children.add(const SizedBox(width: 4));
      children.add(trailing!);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  void _playTrack(BuildContext context, WidgetRef ref) {
    // Reproducir INMEDIATAMENTE
    ref.read(audioPlayerProvider.notifier).play(
      trackId: track.id,
      trackName: track.name,
      artistName: track.artistName,
      albumName: track.albumName,
      coverUrl: track.coverUrl,
      provider: track.source ?? '',
      isrc: track.isrc,
      quality: track.audioQuality,
    );

    // Pre-cargar video y letra EN PARALELO (sin bloquear el audio)
    Future(() {
      ref.read(audioPlayerProvider.notifier).prefetchVideo(track.name, track.artistName);
      ref.read(lyricsProvider.notifier).fetchForTrack(
        trackId: track.id,
        trackName: track.name,
        artistName: track.artistName,
        durationMs: 0,
      );
    });
  }
}

(MapEntry<String, String>, IconData) defaultSourceInfo(String source) {
  switch (normalizeSource(source)) {
    case 'spotify':
      return (const MapEntry('Spotify', 'spotify'), Icons.music_note);
    case 'deezer':
      return (const MapEntry('Deezer', 'deezer'), Icons.audiotrack);
    case 'qobuz':
      return (const MapEntry('Qobuz', 'qobuz'), Icons.radio);
    case 'tidal':
      return (const MapEntry('Tidal', 'tidal'), Icons.waves);
    case 'apple-music':
      return (const MapEntry('Apple Music', 'apple-music'), Icons.apple);
    case 'soundcloud':
      return (const MapEntry('SoundCloud', 'soundcloud'), Icons.cloud);
    case 'pandora':
      return (const MapEntry('Pandora', 'pandora'), Icons.queue_music);
    case 'amazon':
      return (const MapEntry('Amazon Music', 'amazon'), Icons.shopping_bag);
    case 'ytmusic':
      return (const MapEntry('YouTube Music', 'ytmusic'), Icons.play_circle);
    case 'local':
      return (const MapEntry('Local', 'local'), Icons.folder);
    case 'builtin':
      return (const MapEntry('Built-in', 'builtin'), Icons.settings);
    default:
      return (MapEntry(sourceDisplayName(source), source), sourceIcon(source));
  }
}

class _DownloadProgressPill extends StatelessWidget {
  final double progress;
  final String service;
  final ColorScheme colorScheme;
  final BuildContext context;
  final bool isDark;

  const _DownloadProgressPill({
    required this.progress,
    required this.service,
    required this.colorScheme,
    required this.context,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final srcInfo = defaultSourceInfo(service);
    final pct = (progress * 100).round();
    final sourceName = srcInfo.$1.value;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isDark ? AppTheme.warningDark : AppTheme.warningLight).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isDark ? AppTheme.warningDark : AppTheme.warningLight).withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? AppTheme.warningDark : AppTheme.warningLight,
              ),
              strokeCap: StrokeCap.round,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$pct%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.warningDark : AppTheme.warningLight,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final double progress;
  final double size;
  final BuildContext context;
  final bool isDark;

  const _StatusDot({required this.progress, required this.size, required this.context, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isNone = progress <= 0;
    final isCompleted = progress >= 1.0;

    if (isCompleted) {
      return Container(
        width: size,
        height: size,
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
        child: Icon(Icons.check, size: size * 0.7, color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight),
      );
    }

    if (isNone) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight).withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 2,
            backgroundColor: (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight).withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              isDark ? AppTheme.warningDark : AppTheme.warningLight,
            ),
          ),
          Center(
            child: Container(
              width: size * 0.35,
              height: size * 0.35,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.warningDark : AppTheme.warningLight,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final BuildContext context;
  final bool isDark;

  const _Badge({required this.label, required this.color, required this.context, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SelectionCheckbox extends StatelessWidget {
  final bool isSelected;
  final ValueChanged<bool>? onChanged;
  final BuildContext context;

  const _SelectionCheckbox({required this.isSelected, this.onChanged, required this.context});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(this.context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => onChanged?.call(!isSelected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? (isDark ? AppTheme.primaryDark : AppTheme.primaryLight) : Colors.transparent,
          border: Border.all(
            color: isSelected 
                ? (isDark ? AppTheme.primaryDark : AppTheme.primaryLight)
                : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: isDark ? AppTheme.primaryDark.withOpacity(0.4) : AppTheme.primaryLight.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                size: 14,
                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
              )
            : null,
      ),
    );
  }
}
