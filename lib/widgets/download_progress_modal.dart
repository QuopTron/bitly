import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/models/download_item.dart';
import 'package:bitly/providers/download_queue_provider.dart';
import 'package:bitly/providers/extension_provider.dart';
import 'package:bitly/theme/app_theme.dart';
import 'package:bitly/widgets/cached_cover_image.dart';
import 'package:bitly/widgets/glass_container.dart';

class DownloadProgressModal extends ConsumerWidget {
  final String itemId;

  const DownloadProgressModal({super.key, required this.itemId});

  static void show(BuildContext context, String itemId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.95,
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      builder: (context) => DownloadProgressModal(itemId: itemId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(
      downloadQueueLookupProvider.select((lookup) => lookup.byItemId[itemId]),
    );

    if (item == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.pop(context);
      });
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final track = item.track;

    return Container(
      margin: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
      height: MediaQuery.of(context).size.height * 0.6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: AppTheme.modalBlurSigma,
            sigmaY: AppTheme.modalBlurSigma,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: isDark ? AppTheme.modalGradientDark : AppTheme.modalGradientLight,
              border: Border.all(
                color: isDark ? AppTheme.modalBorderDark : AppTheme.modalBorderLight,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: isDark ? AppTheme.primaryDark.withOpacity(0.3) : AppTheme.primaryLight.withOpacity(0.3),
                  blurRadius: 40,
                  spreadRadius: 4,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: isDark ? AppTheme.primaryDark.withOpacity(0.08) : AppTheme.primaryLight.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 0),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 16, bottom: 8),
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                        isDark ? AppTheme.glowDark : AppTheme.glowLight,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? AppTheme.primaryDark.withOpacity(0.4) : AppTheme.primaryLight.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    'Descargando',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      fontSize: 22,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          color: isDark ? AppTheme.primaryDark.withOpacity(0.3) : AppTheme.primaryLight.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Track info with blurred background
                        if (track.coverUrl != null)
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Blurred cover background
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: ImageFiltered(
                                    imageFilter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                                    child: CachedCoverImage(
                                      imageUrl: track.coverUrl!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              // Gradient overlay
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        isDark ? AppTheme.surfaceDark.withOpacity(0.8) : AppTheme.surfaceLight.withOpacity(0.8),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                              // Track info
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: CachedCoverImage(
                                        imageUrl: track.coverUrl ?? '',
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            track.name,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onSurface,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black.withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            track.artistName,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else
                          NeonCard(
                            margin: EdgeInsets.zero,
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(Icons.music_note, size: 50, color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track.name,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                        maxLines: 2,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        track.artistName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        const SizedBox(height: 32),
                        
                        // Progress circle
                        _ProgressIndicator(item: item),
                        
                        const SizedBox(height: 32),
                        
                        // Details card
                        NeonCard(
                          margin: EdgeInsets.zero,
                          padding: const EdgeInsets.all(16),
                          child: _DetailsRow(item: item),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Stop button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              ref.read(downloadQueueProvider.notifier).cancelItem(item.id);
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.stop_rounded),
                            label: const Text('Detener Descarga'),
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.errorContainer,
                              foregroundColor: colorScheme.onErrorContainer,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
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
}

class _ProgressIndicator extends StatelessWidget {
  final DownloadItem item;

  const _ProgressIndicator({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = item.progress;
    final percentage = (progress * 100).toInt();

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Circular progress background
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  isDark ? AppTheme.primaryDark.withOpacity(0.1) : AppTheme.primaryLight.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? AppTheme.primaryDark.withOpacity(0.3) : AppTheme.primaryLight.withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 0),
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: CircularProgressIndicator(
                value: progress > 0 ? progress : null,
                strokeWidth: 8,
                backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                color: colorScheme.primary,
                strokeCap: StrokeCap.round,
              ),
            ),
          ),
          // Progress text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                  shadows: [
                    Shadow(
                      color: isDark ? AppTheme.primaryDark.withOpacity(0.3) : AppTheme.primaryLight.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              if (item.speedMBps > 0)
                Text(
                  '${item.speedMBps.toStringAsFixed(1)} MB/s',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailsRow extends ConsumerWidget {
  final DownloadItem item;

  const _DetailsRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final extensions = ref.watch(extensionProvider.select((s) => s.extensions));
    final currentExt = extensions.where((e) => e.id == item.service).firstOrNull;
    final sourceName = currentExt?.displayName ?? item.service;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Detalles de la Descarga',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _DetailItem(
              icon: Icons.source_rounded,
              label: 'Fuente',
              value: sourceName,
            ),
            GlassDivider(height: 40, indent: 0, vertical: true),
            _DetailItem(
              icon: Icons.high_quality_rounded,
              label: 'Calidad',
              value: item.qualityOverride ?? 'Default',
            ),
            GlassDivider(height: 40, indent: 0, vertical: true),
            _DetailItem(
              icon: Icons.timer_outlined,
              label: 'Estado',
              value: _statusText(item.status),
            ),
          ],
        ),
      ],
    );
  }

  String _statusText(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.queued: return 'En Cola';
      case DownloadStatus.downloading: return 'Bajando';
      case DownloadStatus.finalizing: return 'Finalizando';
      case DownloadStatus.completed: return 'Listo';
      case DownloadStatus.failed: return 'Falló';
      case DownloadStatus.skipped: return 'Saltado';
    }
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 22,
          color: colorScheme.primary.withValues(alpha: 0.8),
          shadows: [
            Shadow(
              color: isDark ? AppTheme.primaryDark.withOpacity(0.3) : AppTheme.primaryLight.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
