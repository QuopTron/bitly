import 'dart:io';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/l10n/l10n.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/providers/audio_player_provider.dart';
import 'package:bitly/providers/lyrics_provider.dart';
import 'package:bitly/providers/download_queue_provider.dart';
import 'package:bitly/providers/library_collections_provider.dart';
import 'package:bitly/services/library/covers/cover_cache_manager.dart';
import 'package:bitly/widgets/playlist_picker_sheet.dart';
import 'package:bitly/utils/clickable_metadata.dart';
import 'package:bitly/screens/queue_tab.dart';

class TrackCollectionQuickActions extends ConsumerWidget {
  final Track track;

  const TrackCollectionQuickActions({super.key, required this.track});

  static void showTrackOptionsSheet(
    BuildContext context,
    WidgetRef ref,
    Track track,
  ) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => _TrackOptionsSheet(track: track),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      icon: Icon(
        Icons.more_vert,
        color: colorScheme.onSurfaceVariant,
        size: 20,
      ),
      onPressed: () => showTrackOptionsSheet(context, ref, track),
      padding: const EdgeInsets.only(left: 12),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

class _TrackOptionsSheet extends ConsumerStatefulWidget {
  final Track track;

  const _TrackOptionsSheet({required this.track});

  @override
  ConsumerState<_TrackOptionsSheet> createState() => _TrackOptionsSheetState();
}

class _TrackOptionsSheetState extends ConsumerState<_TrackOptionsSheet> {
  DownloadHistoryItem? _dbDownloadedItem;

  @override
  void initState() {
    super.initState();
    _checkDatabase();
  }

  Future<void> _checkDatabase() async {
    try {
      final request = HistoryLookupRequest(
        spotifyId: widget.track.id,
        isrc: widget.track.isrc,
        trackName: widget.track.name,
        artistName: widget.track.artistName,
      );
      final item = await ref.read(downloadHistoryProvider.notifier).findExistingTrackAsync(request);
      if (mounted) {
        setState(() {
          _dbDownloadedItem = item;
        });
      }
    } catch (e) {
      debugPrint('_TrackOptionsSheet._checkDatabase error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final t = widget.track;
    final coverUrl = t.coverUrl;

    final isLoved = ref.watch(
      libraryCollectionsProvider.select((state) => state.isLoved(t)),
    );
    final isInWishlist = ref.watch(
      libraryCollectionsProvider.select((state) => state.isInWishlist(t)),
    );
    final downloadedItem = ref.watch(downloadHistoryProvider.select(
      (s) {
        final request = HistoryLookupRequest(
          spotifyId: t.id,
          isrc: t.isrc,
          trackName: t.name,
          artistName: t.artistName,
        );
        return s.findExistingTrack(request);
      },
    ));

    final effectiveDownloadedItem = downloadedItem ?? _dbDownloadedItem;

    Widget? coverWidget;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      if (coverUrl.startsWith('http://') || coverUrl.startsWith('https://')) {
        coverWidget = CachedNetworkImage(
          imageUrl: coverUrl,
          fit: BoxFit.cover,
          memCacheWidth: 200,
          cacheManager: CoverCacheManager.instance,
          errorWidget: (_, _, _) => const SizedBox.shrink(),
        );
      } else {
        coverWidget = Image.file(
          File(coverUrl),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
      }
    }

    final sheetContent = SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Track info header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: coverUrl != null && coverUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: coverUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              memCacheWidth: 96,
                              cacheManager: CoverCacheManager.instance,
                              errorWidget: (_, _, _) => Container(
                                width: 48, height: 48,
                                color: colorScheme.surfaceContainerHighest,
                                child: Icon(Icons.music_note, size: 20, color: colorScheme.onSurfaceVariant),
                              ),
                            )
                          : Container(
                              width: 48, height: 48,
                              color: colorScheme.surfaceContainerHighest,
                              child: Icon(Icons.music_note, size: 20, color: colorScheme.onSurfaceVariant),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.name,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          ClickableArtistName(
                            artistName: t.artistName,
                            artistId: t.artistId,
                            coverUrl: t.coverUrl,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
              // Divider
              Container(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.2), margin: const EdgeInsets.symmetric(horizontal: 16)),
              const SizedBox(height: 6),
              // Options
              _buildGlassOption(
                context, colorScheme,
                icon: isLoved ? Icons.favorite : Icons.favorite_border,
                iconColor: isLoved ? colorScheme.error : null,
                title: isLoved
                    ? context.l10n.trackOptionRemoveFromLoved
                    : context.l10n.trackOptionAddToLoved,
                onTap: () async {
                  final notifier = ref.read(libraryCollectionsProvider.notifier);
                  final l10n = context.l10n;
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  final added = await notifier.toggleLoved(t);
                  messenger.showSnackBar(
                    SnackBar(content: Text(added ? l10n.collectionAddedToLoved(t.name) : l10n.collectionRemovedFromLoved(t.name))),
                  );
                },
              ),
              _buildGlassOption(
                context, colorScheme,
                icon: isInWishlist ? Icons.star : Icons.star_border,
                iconColor: isInWishlist ? colorScheme.primary : null,
                title: isInWishlist
                    ? context.l10n.trackOptionRemoveFromWishlist
                    : context.l10n.trackOptionAddToWishlist,
                onTap: () async {
                  final notifier = ref.read(libraryCollectionsProvider.notifier);
                  final l10n = context.l10n;
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  final added = await notifier.toggleWishlist(t);
                  messenger.showSnackBar(
                    SnackBar(content: Text(added ? l10n.collectionAddedToWishlist(t.name) : l10n.collectionRemovedFromWishlist(t.name))),
                  );
                },
              ),
              _buildGlassOption(
                context, colorScheme,
                icon: Icons.playlist_add,
                title: context.l10n.collectionAddToPlaylist,
                onTap: () {
                  Navigator.pop(context);
                  showAddTrackToPlaylistSheet(context, ref, t);
                },
              ),
              Container(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.2), margin: const EdgeInsets.symmetric(horizontal: 16)),
              const SizedBox(height: 6),
              _buildGlassOption(
                context, colorScheme,
                icon: Icons.play_circle_filled,
                title: 'Reproducir',
                subtitle: t.source != null ? 'desde ${t.source}' : null,
                onTap: () {
                  Navigator.pop(context);
                  // Reproducir INMEDIATAMENTE
                  ref.read(audioPlayerProvider.notifier).play(
                    trackId: t.id, trackName: t.name, artistName: t.artistName,
                    albumName: t.albumName, coverUrl: t.coverUrl,
                    provider: t.source ?? 'deezer', isrc: t.isrc,
                  );
                  
                  // Pre-cargar video y letra EN PARALELO (sin bloquear el audio)
                  Future(() {
                    ref.read(audioPlayerProvider.notifier).prefetchVideo(t.name, t.artistName);
                    ref.read(lyricsProvider.notifier).fetchForTrack(
                      trackId: t.id,
                      trackName: t.name,
                      artistName: t.artistName,
                      durationMs: 0,
                    );
                  });
                },
              ),
              if (effectiveDownloadedItem != null)
                _buildGlassOption(
                  context, colorScheme,
                  icon: Icons.delete_outline,
                  iconColor: colorScheme.error,
                  title: 'Eliminar descarga',
                  subtitle: 'Borra el archivo y el historial',
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final name = t.name;
                    final historyNotifier = ref.read(downloadHistoryProvider.notifier);
                    
                    Navigator.pop(context);
                    
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('¿Eliminar descarga?'),
                        content: Text('Se borrará "$name" de tu dispositivo.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );
 
                     if (confirmed == true) {
                       await historyNotifier.deleteDownload(effectiveDownloadedItem);
                       FileExistsListenableCache.instance.invalidate(effectiveDownloadedItem.filePath);
                       messenger.showSnackBar(
                         SnackBar(content: Text('Eliminado: $name')),
                       );
                     }
                  },
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );

    // Glass wrapper
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Stack(
          children: [
            // Blurred cover background
            if (coverWidget != null)
              Positioned.fill(
                child: ClipRRect(child: coverWidget),
              ),
            // Frost overlay
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            // Color overlay
            Positioned.fill(
              child: Container(color: colorScheme.surface.withValues(alpha: 0.75)),
            ),
            // Subtle border
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 0.5)),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
              ),
            ),
            // Content
            sheetContent,
          ],
        ),
    );
  }

  Widget _buildGlassOption(
    BuildContext context,
    ColorScheme colorScheme, {
    required IconData icon,
    Color? iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    color: (iconColor ?? colorScheme.primary).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: iconColor ?? colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: colorScheme.onSurface)),
                      if (subtitle != null)
                        Text(subtitle, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
