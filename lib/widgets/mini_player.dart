import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/providers/audio_player_provider.dart';
import 'package:bitly/providers/lyrics_provider.dart';
import 'package:bitly/providers/playback_queue_provider.dart';
import 'package:bitly/screens/player_screen.dart';

bool _isLocalCover(String url) =>
    !url.startsWith('http://') && !url.startsWith('https://');

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPlayerProvider);
    final queue = ref.watch(playbackQueueProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ref.watch(lyricsProvider.select((s) => s.isReady)); // keep lyrics provider alive
    final colorScheme = Theme.of(context).colorScheme;

    if (state.trackId == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PlayerScreen(),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                    (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                  ],
                ),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.25),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(9999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    // Cover art
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9999),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primaryContainer,
                              colorScheme.primaryContainer.withOpacity(0.7),
                            ],
                          ),
                        ),
                        child: state.coverUrl != null
                            ? (_isLocalCover(state.coverUrl!)
                                ? Image.file(
                                    File(state.coverUrl!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Icon(
                                      Icons.music_note,
                                      color: colorScheme.onPrimaryContainer,
                                      size: 24,
                                    ),
                                  )
                                : Image.network(
                                    state.coverUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Icon(
                                      Icons.music_note,
                                      color: colorScheme.onPrimaryContainer,
                                      size: 24,
                                    ),
                                  ))
                            : Icon(
                                Icons.music_note,
                                color: colorScheme.onPrimaryContainer,
                                size: 24,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Track info
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.trackName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            state.artistName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFFB5B5B5)
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Controls or Loading indicator
                    if (!state.isLoading)
                      Row(
                        children: [
                          _buildControlButton(
                            icon: Icons.skip_previous,
                            onPressed: queue.canGoPrevious
                                ? () => ref.read(audioPlayerProvider.notifier).playQueuePrevious()
                                : null,
                            color: queue.canGoNext || queue.canGoPrevious
                                ? (isDark ? Colors.white : colorScheme.onSurface)
                                : (isDark ? const Color(0xFF7A7A7A) : colorScheme.onSurfaceVariant.withOpacity(0.4)),
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          _buildControlButton(
                            icon: state.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            onPressed: () => ref.read(audioPlayerProvider.notifier).togglePlayPause(),
                            color: isDark ? const Color(0xFF00F5B0) : colorScheme.primary,
                            size: 32,
                          ),
                          const SizedBox(width: 4),
                          _buildControlButton(
                            icon: Icons.skip_next,
                            onPressed: queue.canGoNext
                                ? () => ref.read(audioPlayerProvider.notifier).playQueueNext()
                                : null,
                            color: queue.canGoNext
                                ? (isDark ? Colors.white : colorScheme.onSurface)
                                : (isDark ? const Color(0xFF7A7A7A) : colorScheme.onSurfaceVariant.withOpacity(0.4)),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                        ],
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? const Color(0xFF00F5B0) : colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Cargando...',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
    required double size,
  }) {
    return IconButton(
      icon: Icon(icon, size: size),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      color: color,
    );
  }
}
