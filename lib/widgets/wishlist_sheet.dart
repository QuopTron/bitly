import 'dart:io';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/providers/audio_player_provider.dart';
import 'package:bitly/providers/lyrics_provider.dart';
import 'package:bitly/providers/library_collections_provider.dart';
import 'package:bitly/services/biblioteca/portadas/cover_cache_manager.dart';

class WishlistSheet extends ConsumerWidget {
  const WishlistSheet({super.key});

  static void show(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.9, // 90% width max
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => const WishlistSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final wishlist = ref.watch(
      libraryCollectionsProvider.select((state) => state.wishlist),
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.surfaceContainerHighest.withOpacity(0.8),
                    colorScheme.surface.withOpacity(0.6),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned.fill(
            child: Container(color: colorScheme.surface.withOpacity(0.3)),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5)),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.star, size: 18, color: colorScheme.primary),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Wishlist',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${wishlist.length} ${wishlist.length == 1 ? 'track' : 'tracks'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (wishlist.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(Icons.star_outline, size: 48, color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'No tracks in Wishlist',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add tracks from the track menu',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.55,
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        itemCount: wishlist.length,
                        itemBuilder: (context, index) {
                          final entry = wishlist[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: _WishlistTrackTile(entry: entry),
                          );
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WishlistTrackTile extends ConsumerWidget {
  final CollectionTrackEntry entry;

  const _WishlistTrackTile({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final track = entry.track;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Reproducir INMEDIATAMENTE
          ref.read(audioPlayerProvider.notifier).play(
            trackId: track.id,
            trackName: track.name,
            artistName: track.artistName,
            albumName: track.albumName,
            coverUrl: track.coverUrl,
            provider: track.source ?? 'deezer',
            isrc: track.isrc,
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
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: track.coverUrl != null && track.coverUrl!.isNotEmpty
                    ? (track.coverUrl!.startsWith('http://') || track.coverUrl!.startsWith('https://')
                        ? CachedNetworkImage(
                            imageUrl: track.coverUrl!,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            memCacheWidth: 88,
                            cacheManager: CoverCacheManager.instance,
                            errorWidget: (_, _, _) => _coverFallback(colorScheme, 44),
                          )
                        : Image.file(
                            File(track.coverUrl!),
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _coverFallback(colorScheme, 44),
                          ))
                    : _coverFallback(colorScheme, 44),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      track.artistName,
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.play_circle_fill,
                size: 20,
                color: colorScheme.primary.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverFallback(ColorScheme colorScheme, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Icon(Icons.music_note, size: size * 0.4, color: colorScheme.onSurfaceVariant),
    );
  }
}
