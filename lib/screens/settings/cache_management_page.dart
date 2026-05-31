import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitly/l10n/l10n.dart';
import 'package:bitly/services/biblioteca/portadas/cover_cache_manager.dart';
import 'package:bitly/services/núcleo/platform_bridge.dart';
import 'package:bitly/utils/app_bar_layout.dart';
import 'package:bitly/widgets/factory_reset_dialog.dart';
import 'package:bitly/widgets/video_cache_settings.dart';

class CacheManagementPage extends ConsumerStatefulWidget {
  const CacheManagementPage({super.key});

  @override
  ConsumerState<CacheManagementPage> createState() =>
      _CacheManagementPageState();
}

class _CacheManagementPageState extends ConsumerState<CacheManagementPage> {
  // Keep in sync with ExploreNotifier keys.
  static const String _exploreCacheKey = 'explore_home_feed_cache';
  static const String _exploreCacheTsKey = 'explore_home_feed_ts';

  _CacheOverview? _overview;
  bool _isLoading = true;
  String? _busyAction;

  @override
  void initState() {
    super.initState();
    _refreshOverview();
  }

  bool get _isBusy => _busyAction != null;

  Future<void> _refreshOverview() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final overview = await _buildOverview();
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.snackbarError(e.toString()))));
    }
  }

  Future<_CacheOverview> _buildOverview() async {
    final appCacheDir = await getApplicationCacheDirectory();
    final tempDir = await getTemporaryDirectory();
    final coverStats = await CoverCacheManager.getStats();

    var totalBytes = 0;
    try {
      await for (final entity in appCacheDir.list(recursive: true, followLinks: false)) {
        if (entity is File) totalBytes += await entity.length();
      }
    } catch (_) {}
    try {
      await for (final entity in tempDir.list(recursive: true, followLinks: false)) {
        if (entity is File) totalBytes += await entity.length();
      }
    } catch (_) {}

    totalBytes += coverStats.totalSizeBytes;

    return _CacheOverview(totalBytes: totalBytes);
  }

  Future<void> _clearAllCaches() async {
    final cacheDir = await getApplicationCacheDirectory();
    final tempDir = await getTemporaryDirectory();
    await _clearDir(cacheDir.path);
    await _clearDir(tempDir.path);
    await CoverCacheManager.clearCache();
    await PlatformBridge.clearTrackCache();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('explore_home_feed_cache');
    await prefs.remove('explore_home_feed_ts');
  }

  Future<void> _clearDir(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        await entity.delete(recursive: true);
      }
    } catch (_) {}
    try {
      await dir.create(recursive: true);
    } catch (_) {}
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final topPadding = normalizedHeaderTopPadding(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120 + topPadding,
            collapsedHeight: kToolbarHeight,
            floating: false,
            pinned: true,
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                tooltip: context.l10n.cacheRefresh,
                onPressed: _isBusy ? null : _refreshOverview,
                icon: const Icon(Icons.refresh),
              ),
            ],
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final maxHeight = 120 + topPadding;
                final minHeight = kToolbarHeight + topPadding;
                final expandRatio = ((constraints.maxHeight - minHeight) / (maxHeight - minHeight)).clamp(0.0, 1.0);
                final leftPadding = 56 - (32 * expandRatio);
                return FlexibleSpaceBar(
                  expandedTitleScale: 1.0,
                  titlePadding: EdgeInsets.only(left: leftPadding, bottom: 16),
                  title: Text(
                    context.l10n.cacheTitle,
                    style: TextStyle(fontSize: 20 + (8 * expandRatio), fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                  ),
                );
              },
            ),
          ),

          if (_isLoading || _overview == null)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.cacheEstimatedTotal(_formatBytes(_overview!.totalBytes)),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _isBusy
                              ? null
                              : () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text(context.l10n.cacheClearAllConfirmTitle),
                                      content: Text(context.l10n.cacheClearAllConfirmMessage),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.dialogCancel)),
                                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.l10n.dialogClear)),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true || !mounted) return;
                                  setState(() => _busyAction = 'clear_all');
                                  try {
                                    await _clearAllCaches();
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.cacheClearSuccess(context.l10n.cacheClearAll))));
                                  } catch (e) {
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.snackbarError(e.toString()))));
                                  } finally {
                                    if (mounted) { setState(() => _busyAction = null); _refreshOverview(); }
                                  }
                                },
                          icon: _busyAction == 'clear_all'
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.delete_sweep_outlined),
                          label: Text(context.l10n.cacheClearAll),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _isBusy ? null : _refreshOverview,
                          icon: const Icon(Icons.refresh),
                          label: Text(context.l10n.cacheRefreshStats),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

           SliverToBoxAdapter(
             child: Container(
               margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(
                 color: colorScheme.primaryContainer.withValues(alpha: 0.28),
                 borderRadius: BorderRadius.circular(18),
               ),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Row(
                     children: [
                       Icon(Icons.videocam_outlined, color: colorScheme.primary, size: 20),
                       const SizedBox(width: 8),
                       Text(
                         'Caché de Videos',
                         style: Theme.of(context).textTheme.titleMedium?.copyWith(
                           fontWeight: FontWeight.w700,
                           color: colorScheme.onPrimaryContainer,
                         ),
                       ),
                     ],
                   ),
                   const SizedBox(height: 8),
                   Text(
                     'Administra los videos cacheados para reproducción offline y optimiza el espacio de almacenamiento.',
                     style: Theme.of(context).textTheme.bodySmall?.copyWith(
                       color: colorScheme.onSurfaceVariant,
                     ),
                   ),
                   const SizedBox(height: 16),
                   FilledButton.icon(
                     onPressed: () {
                       Navigator.of(context).push(
                         MaterialPageRoute(
                           builder: (context) => const VideoCacheSettings(),
                         ),
                       );
                     },
                     icon: const Icon(Icons.settings_outlined),
                     label: const Text('Administrar caché de videos'),
                   ),
                 ],
               ),
             ),
           ),
           
           SliverToBoxAdapter(
             child: Container(
               margin: const EdgeInsets.fromLTRB(16, 12, 16, 24),
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(
                 color: colorScheme.errorContainer.withValues(alpha: 0.15),
                 borderRadius: BorderRadius.circular(18),
                 border: Border.all(color: colorScheme.error.withValues(alpha: 0.2)),
               ),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Row(
                     children: [
                       Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 20),
                       const SizedBox(width: 8),
                       Text(
                         'Restablecimiento Completo',
                         style: Theme.of(context).textTheme.titleMedium?.copyWith(
                           fontWeight: FontWeight.w700,
                           color: colorScheme.error,
                         ),
                       ),
                     ],
                   ),
                   const SizedBox(height: 8),
                   Text(
                     'Elimina absolutamente todos los datos de la aplicación (BSDs, historial, likes) y opcionalmente los archivos físicos.',
                     style: Theme.of(context).textTheme.bodySmall?.copyWith(
                       color: colorScheme.onSurfaceVariant,
                     ),
                   ),
                   const SizedBox(height: 16),
                   FilledButton.icon(
                     onPressed: () => FactoryResetDialog.show(context),
                     style: FilledButton.styleFrom(
                       backgroundColor: colorScheme.error,
                       foregroundColor: colorScheme.onError,
                     ),
                     icon: const Icon(Icons.factory_outlined),
                     label: const Text('Restablecimiento de fábrica'),
                   ),
                 ],
               ),
             ),
           ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _CacheOverview {
  final int totalBytes;

  const _CacheOverview({required this.totalBytes});
}
