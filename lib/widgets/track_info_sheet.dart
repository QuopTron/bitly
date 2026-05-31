import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/l10n/l10n.dart';
import 'package:bitly/providers/download_queue_provider.dart';
import 'package:bitly/utils/source_icons.dart';
import 'package:bitly/widgets/cached_cover_image.dart';

void showTrackInfoSheet(BuildContext context, Track track) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    showDragHandle: false,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    constraints: BoxConstraints(
      maxWidth: MediaQuery.of(context).size.width * 0.9, // 90% width max
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (_) => Consumer(
      builder: (context, ref, child) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final l10n = context.l10n;
        final history = ref.watch(downloadHistoryProvider);

        final downloaded = <DownloadHistoryItem>[];
        final normName = normalizeForMatch(track.name);
        final normArtist = normalizeForMatch(track.artistName);
        for (final item in history.items) {
          if (item.isrc != null &&
              track.isrc != null &&
              item.isrc == track.isrc) {
            downloaded.add(item);
          } else if (normalizeForMatch(item.trackName) == normName &&
              normalizeForMatch(item.artistName) == normArtist) {
            downloaded.add(item);
          }
        }

        Widget? coverWidget;
        if (track.coverUrl != null) {
          if (track.coverUrl!.startsWith('http://') ||
              track.coverUrl!.startsWith('https://')) {
            coverWidget = CachedCoverImage(
              imageUrl: track.coverUrl!,
              fit: BoxFit.cover,
            );
          } else {
            coverWidget = Image.file(
              File(track.coverUrl!),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            );
          }
        }

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Stack(
            children: [
              if (coverWidget != null) Positioned.fill(child: coverWidget),
              Positioned.fill(
                child: ClipRRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                    color: colorScheme.surface.withValues(alpha: 0.75)),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 0.5),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 16, 20, 4),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: coverWidget ??
                                  Container(
                                    color: colorScheme
                                        .surfaceContainerHighest),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.name,
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  track.artistName,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(
                                          color: colorScheme
                                              .onSurfaceVariant),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 1,
                      color: colorScheme.outlineVariant
                          .withValues(alpha: 0.2),
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: Column(
                          children: [
                            _infoTile(
                              icon: Icons.album_rounded,
                              label: l10n.trackAlbum,
                              value: track.albumName.isNotEmpty
                                  ? track.albumName
                                  : '—',
                              colorScheme: colorScheme,
                            ),
                            const SizedBox(height: 6),
                            if (track.audioQuality != null &&
                                track.audioQuality!.isNotEmpty)
                              _infoTile(
                                icon: Icons.high_quality_rounded,
                                label: l10n.trackAudioQuality,
                                value: track.audioQuality!,
                                colorScheme: colorScheme,
                              ),
                            if (track.audioQuality != null &&
                                track.audioQuality!.isNotEmpty)
                              const SizedBox(height: 6),
                            if (track.duration > 0)
                              _infoTile(
                                icon: Icons.access_time_rounded,
                                label: l10n.trackDuration,
                                value:
                                    '${track.duration ~/ 60}:${(track.duration % 60).toString().padLeft(2, '0')}',
                                colorScheme: colorScheme,
                              ),
                            if (track.duration > 0)
                              const SizedBox(height: 6),
                            if (track.releaseDate != null &&
                                track.releaseDate!.isNotEmpty)
                              _infoTile(
                                icon: Icons.calendar_month_rounded,
                                label: l10n.trackReleaseDate,
                                value: track.releaseDate!,
                                colorScheme: colorScheme,
                              ),
                            if (track.releaseDate != null &&
                                track.releaseDate!.isNotEmpty)
                              const SizedBox(height: 6),
                            if (track.isrc != null &&
                                track.isrc!.isNotEmpty)
                              _infoTile(
                                icon: Icons.fingerprint_rounded,
                                label: 'ISRC',
                                value: track.isrc!,
                                colorScheme: colorScheme,
                              ),
                            if (track.isrc != null &&
                                track.isrc!.isNotEmpty)
                              const SizedBox(height: 6),
                            if (track.trackNumber != null)
                              _infoTile(
                                icon: Icons.format_list_numbered_rounded,
                                label: l10n.trackTrackNumber,
                                value: '${track.trackNumber}',
                                colorScheme: colorScheme,
                              ),
                            if (downloaded.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _sectionHeader(
                                icon: Icons.folder_rounded,
                                label: 'Descargas',
                                count: downloaded.length,
                                colorScheme: colorScheme,
                              ),
                              const SizedBox(height: 8),
                              for (final item in downloaded)
                                _DownloadedSourceCard(
                                    item: item, colorScheme: colorScheme),
                            ],
                          ],
                        ),
                      ),
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

({IconData icon, String color}) _sourceTheme(String service, ColorScheme cs) {
  final norm = normalizeSource(service);
  switch (norm) {
    case 'qobuz':
      return (icon: Icons.radio, color: '#1DB954');
    case 'deezer':
      return (icon: Icons.audiotrack, color: '#A238FF');
    case 'tidal':
      return (icon: Icons.waves, color: '#0FF');
    case 'spotify':
      return (icon: Icons.music_note, color: '#1DB954');
    case 'apple-music':
      return (icon: Icons.apple, color: '#FA233B');
    case 'local':
      return (icon: Icons.folder, color: '#888');
    default:
      return (icon: sourceIcon(service), color: '#888');
  }
}

String _sourceDisplayName(String service) {
  return sourceDisplayName(service);
}

Widget _sectionHeader({
  required IconData icon,
  required String label,
  required int count,
  required ColorScheme colorScheme,
}) {
  return Row(
    children: [
      Icon(icon, size: 16, color: colorScheme.primary),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colorScheme.primary,
          ),
        ),
      ),
    ],
  );
}

class _DownloadedSourceCard extends StatelessWidget {
  final DownloadHistoryItem item;
  final ColorScheme colorScheme;

  const _DownloadedSourceCard({
    required this.item,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final srcName = _sourceDisplayName(item.service ?? '');
    final srcTheme = _sourceTheme(item.service ?? '', colorScheme);
    final quality = [
      if (item.quality != null && item.quality!.isNotEmpty) item.quality,
      if (item.format != null && item.format!.isNotEmpty) item.format,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(srcTheme.icon,
                    size: 16, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  srcName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              if (quality.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    quality.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _detailRow('Códec', item.format ?? '—', colorScheme),
          if (item.sampleRate != null)
            _detailRow('Sample rate', '${item.sampleRate} Hz', colorScheme),
          if (item.bitDepth != null)
            _detailRow('Bit depth', '${item.bitDepth}-bit', colorScheme),
          if (item.bitrate != null)
            _detailRow('Bitrate', '${item.bitrate} kbps', colorScheme),
          _detailRow('Ubicación', item.filePath, colorScheme),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _infoTile({
  required IconData icon,
  required String label,
  required String value,
  required ColorScheme colorScheme,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
