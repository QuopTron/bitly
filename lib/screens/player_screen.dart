import 'dart:io';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/providers/audio_player_provider.dart';
import 'package:bitly/providers/playback_queue_provider.dart';
import 'package:media_kit_video/media_kit_video.dart' show Video, VideoController;
import 'package:bitly/services/biblioteca/portadas/cover_cache_manager.dart';
import 'package:bitly/widgets/audio_visualizer.dart';
import 'package:bitly/widgets/cached_cover_image.dart';
import 'package:bitly/widgets/lyrics_sheet.dart';
import 'package:bitly/providers/view_mode_provider.dart';
import 'package:bitly/widgets/track_card.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _isVideoLoading = false;
  bool _videoError = false;

  Future<void> _onToggleView() async {
    final mode = ref.read(viewModeProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);
    final playerState = ref.read(audioPlayerProvider);
    
    if (mode == ViewMode.cover) {
      final videoReady = playerState.isVideoReady;
      
      // Show loading state immediately
      setState(() {
        _isVideoLoading = true;
        _videoError = false;
      });
      
      try {
        // Toggle view mode first for smoother transition
        ref.read(viewModeProvider.notifier).toggle();
        
        // Start video if not ready
        if (!videoReady) {
          await notifier.startVideo(
            playerState.trackName ?? '',
            playerState.artistName ?? '',
          );
        }
        
        // Seek video to current audio position
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final pos = ref.read(audioPlayerProvider).position;
          if (pos > Duration.zero) {
            notifier.playVideo(pos);
          } else {
            notifier.playVideo();
          }
        });
        
      } catch (e) {
        debugPrint('Video toggle failed: $e');
        _videoError = true;
        // Toggle back if video failed to load
        ref.read(viewModeProvider.notifier).toggle();
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar video: ${e.toString().split(':').last}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isVideoLoading = false);
      }
    } else {
      ref.read(viewModeProvider.notifier).toggle();
      notifier.pauseVideo();
      setState(() => _videoError = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerProvider);
    final queueState = ref.watch(playbackQueueProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final viewMode = ref.watch(viewModeProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Glassmorphism background
          _buildBackground(playerState.coverUrl, viewMode, colorScheme, videoController: playerState.videoController),
          // Foreground content
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        'Now Playing',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.lyrics_outlined),
                            tooltip: 'Letra',
                            onPressed: () => showLyricsSheet(context),
                          ),
                          IconButton(
                            icon: const Icon(Icons.queue_music),
                            onPressed: () => _showQueueSheet(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Cover / Visualizer
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            children: [
                              if (viewMode == ViewMode.visualizer)
                                _buildVideoContent(colorScheme)
                              else
                                _buildCover(playerState.coverUrl, colorScheme),
               Positioned(
                 right: 8,
                 bottom: 8,
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     // Botón de toggle de vista
                     GestureDetector(
                       onTap: _onToggleView,
                       child: Container(
                         width: 28,
                         height: 28,
                         decoration: BoxDecoration(
                           shape: BoxShape.circle,
                           color: viewMode == ViewMode.cover
                               ? colorScheme.primary.withValues(alpha: 0.9)
                               : colorScheme.secondary.withValues(alpha: 0.9),
                           border: Border.all(color: colorScheme.surface, width: 2),
                           boxShadow: [
                             BoxShadow(
                               color: Colors.black.withValues(alpha: 0.3),
                               blurRadius: 4,
                               offset: const Offset(0, 2),
                             ),
                           ],
                         ),
                         child: Center(
                           child: Icon(
                             viewMode == ViewMode.cover
                                 ? Icons.equalizer
                                 : Icons.art_track,
                             size: 14,
                             color: colorScheme.surface,
                      ),
                    ),
                  ),
                  ),
                  if (playerState.isVideoReady && viewMode == ViewMode.visualizer)
                   Positioned(
                     bottom: 16,
                     right: 16,
                     child: FloatingActionButton(
                       mini: true,
                       backgroundColor: Colors.black.withOpacity(0.7),
                       onPressed: () {
                         ref.read(audioPlayerProvider.notifier).resyncAudioVideo();
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(
                             content: Text('Resincronizando audio y video...'),
                             duration: Duration(seconds: 1),
                           ),
                         );
                       },
                       child: Icon(Icons.sync, size: 18, color: Colors.white),
                     ),
                   ),
                     const SizedBox(width: 8),
                     // Indicador de sincronización
                     if (playerState.isVideoReady)
                       Container(
                         width: 28,
                         height: 28,
                         decoration: BoxDecoration(
                           shape: BoxShape.circle,
                           color: playerState.isAudioVideoSynced
                               ? Colors.green.withValues(alpha: 0.9)
                               : Colors.orange.withValues(alpha: 0.9),
                           border: Border.all(color: colorScheme.surface, width: 2),
                         ),
                         child: Center(
                           child: Icon(
                             playerState.isAudioVideoSynced
                                 ? Icons.sync
                                 : Icons.sync_problem,
                             size: 14,
                             color: colorScheme.surface,
                           ),
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

                const SizedBox(height: 8),

                // Track info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        playerState.trackName ?? 'Unknown Track',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        playerState.artistName ?? 'Unknown Artist',
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (playerState.localPath != null)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Local',
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Slider(
                        value: playerState.duration.inMilliseconds > 0
                            ? playerState.position.inMilliseconds /
                                playerState.duration.inMilliseconds
                            : 0,
                        activeColor: colorScheme.primary,
                        inactiveColor: colorScheme.onSurface.withValues(alpha: 0.2),
                        onChanged: (value) {
                          final position = Duration(
                            milliseconds:
                                (value * playerState.duration.inMilliseconds).round(),
                          );
                          ref.read(audioPlayerProvider.notifier).seek(position);
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(playerState.position),
                                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                            Text(_formatDuration(playerState.duration),
                                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildShuffleButton(queueState, colorScheme),
                      _buildPreviousButton(queueState, colorScheme),
                      _buildPlayPauseButton(playerState, colorScheme),
                      _buildNextButton(queueState, colorScheme),
                      _buildRepeatButton(queueState, colorScheme),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(String? coverUrl, ViewMode viewMode, ColorScheme colorScheme, {VideoController? videoController}) {
    if (viewMode == ViewMode.visualizer) {
      final vc = videoController ?? ref.read(audioPlayerProvider.notifier).videoController;
      if (vc != null) {
        return Stack(
          children: [
            Positioned.fill(
              child: Video(controller: vc, fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned.fill(
              child: Container(color: colorScheme.surface.withValues(alpha: 0.6)),
            ),
          ],
        );
      }
    }

    Widget? coverWidget;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      if (coverUrl.startsWith('http://') || coverUrl.startsWith('https://')) {
        coverWidget = CachedNetworkImage(
          imageUrl: coverUrl,
          fit: BoxFit.cover,
          memCacheWidth: 300,
          cacheManager: CoverCacheManager.instance,
          errorWidget: (_, _, _) => const SizedBox.shrink(),
        );
      } else {
        final localPath = coverUrl.startsWith('file://') ? coverUrl.substring(7) : coverUrl;
        coverWidget = Image.file(File(localPath), fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
      }
    }

    return Stack(
      children: [
        if (coverWidget != null)
          Positioned.fill(child: coverWidget),
        Positioned.fill(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned.fill(
          child: Container(color: colorScheme.surface.withValues(alpha: 0.7)),
        ),
      ],
    );
  }

  Widget _buildCover(String? coverUrl, ColorScheme colorScheme) {
    if (coverUrl == null || coverUrl.isEmpty) {
      return _coverPlaceholder(colorScheme);
    }

    String? localPath;
    if (coverUrl.startsWith('file://')) {
      localPath = coverUrl.substring(7);
    } else if (!coverUrl.startsWith('http://') && !coverUrl.startsWith('https://')) {
      localPath = coverUrl;
    }

    if (localPath != null) {
      return Image.file(File(localPath), fit: BoxFit.cover, width: double.infinity, height: double.infinity,
        errorBuilder: (_, _, _) => _coverPlaceholder(colorScheme),
      );
    }

    return CachedCoverImage(
      imageUrl: coverUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }

  Widget _buildVideoContent(ColorScheme colorScheme) {
    final playerState = ref.watch(audioPlayerProvider);
    
    if (_isVideoLoading) {
      return Container(
        color: colorScheme.surfaceContainerHighest,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32, height: 32,
                child: CircularProgressIndicator(strokeWidth: 3, color: colorScheme.primary),
              ),
              const SizedBox(height: 12),
              Text('Buscando video...',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
            ],
          ),
        ),
      );
    }

     final vc = playerState.videoController;
    if (vc != null) {
      return Stack(
        children: [
          Video(controller: vc, fit: BoxFit.cover),
          // Add a subtle loading indicator while buffering
          if (playerState.isLoading)
            Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary.withOpacity(0.7)),
                ),
              ),
            ),
          // Mostrar estado de sincronización
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    playerState.isAudioVideoSynced ? Icons.sync : Icons.sync_problem,
                    size: 14,
                    color: playerState.isAudioVideoSynced ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    playerState.isAudioVideoSynced ? 'Sincronizado' : 'Sincronizando...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (playerState.isVideoReady) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Fuente: ${ref.read(audioPlayerProvider.notifier).currentVideoSource}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_videoError || (!playerState.isVideoReady && !_isVideoLoading)) {
      return Container(
        color: colorScheme.surfaceContainerHighest,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off, size: 48, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
              const SizedBox(height: 8),
              Text('Video no disponible',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () async {
                  setState(() => _isVideoLoading = true);
                  try {
                    await ref.read(audioPlayerProvider.notifier).startVideo(
                      playerState.trackName ?? '',
                      playerState.artistName ?? '',
                    );
                  } catch (e) {
                    setState(() => _videoError = true);
                  } finally {
                    setState(() => _isVideoLoading = false);
                  }
                },
                child: Text('Reintentar', style: TextStyle(color: colorScheme.primary, fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: const AudioVisualizer(),
    );
  }

  Widget _coverPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.music_note, size: 80, color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildPlayPauseButton(AudioPlayerState state, ColorScheme colorScheme) {
    final isLoading = state.isLoading || state.isDownloading;
    return GestureDetector(
      onTap: () {
        if (isLoading) return;
        ref.read(audioPlayerProvider.notifier).togglePlayPause();
      },
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: isLoading
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: colorScheme.onPrimary,
                ),
              )
            : Icon(
                state.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 36,
                color: colorScheme.onPrimary,
              ),
      ),
    );
  }

  Widget _buildPreviousButton(PlaybackQueueState queue, ColorScheme colorScheme) {
    final enabled = queue.canGoPrevious;
    return IconButton(
      icon: Icon(
        Icons.skip_previous,
        size: 32,
        color: enabled ? colorScheme.onSurface : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      ),
      onPressed: enabled
          ? () => ref.read(audioPlayerProvider.notifier).playQueuePrevious()
          : null,
    );
  }

  Widget _buildNextButton(PlaybackQueueState queue, ColorScheme colorScheme) {
    final enabled = queue.canGoNext;
    return IconButton(
      icon: Icon(
        Icons.skip_next,
        size: 32,
        color: enabled ? colorScheme.onSurface : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      ),
      onPressed: enabled
          ? () => ref.read(audioPlayerProvider.notifier).playQueueNext()
          : null,
    );
  }

  Widget _buildShuffleButton(PlaybackQueueState queue, ColorScheme colorScheme) {
    return IconButton(
      icon: Icon(
        Icons.shuffle,
        size: 24,
        color: queue.isShuffled
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
      onPressed: () {
        ref.read(playbackQueueProvider.notifier).toggleShuffle();
      },
    );
  }

  Widget _buildRepeatButton(PlaybackQueueState queue, ColorScheme colorScheme) {
    IconData icon;
    Color color;
    switch (queue.repeatMode) {
      case QueueRepeatMode.none:
        icon = Icons.repeat;
        color = colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
        break;
      case QueueRepeatMode.all:
        icon = Icons.repeat;
        color = colorScheme.primary;
        break;
      case QueueRepeatMode.one:
        icon = Icons.repeat_one;
        color = colorScheme.primary;
        break;
    }
    return IconButton(
      icon: Icon(icon, size: 24, color: color),
      onPressed: () {
        ref.read(playbackQueueProvider.notifier).cycleQueueRepeatMode();
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showQueueSheet(BuildContext context) {
    final queueState = ref.read(playbackQueueProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final coverUrl = ref.read(audioPlayerProvider).coverUrl;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              _queueSheetBackground(coverUrl, colorScheme),
              SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Playback Queue',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: queueState.items.length,
                        itemBuilder: (context, index) {
                          final item = queueState.items[index];
                          final isCurrent = index == queueState.currentIndex;
                          return TrackCard(
                            track: item.track,
                            isCurrentTrack: isCurrent,
                            trailing: isCurrent
                                ? Icon(Icons.play_arrow, color: colorScheme.primary)
                                : IconButton(
                                    icon: Icon(Icons.delete_outline, size: 20, color: colorScheme.onSurfaceVariant),
                                    onPressed: () {
                                      ref.read(playbackQueueProvider.notifier).removeAt(index);
                                      Navigator.pop(context);
                                    },
                                  ),
                            onTap: () {
                              ref.read(playbackQueueProvider.notifier).goToIndex(index);
                              ref.read(audioPlayerProvider.notifier).playFromQueue();
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _queueSheetBackground(String? coverUrl, ColorScheme colorScheme) {
    Widget? coverWidget;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      if (coverUrl.startsWith('http://') || coverUrl.startsWith('https://')) {
        coverWidget = CachedNetworkImage(
          imageUrl: coverUrl,
          fit: BoxFit.cover,
          memCacheWidth: 300,
          cacheManager: CoverCacheManager.instance,
          errorWidget: (_, _, _) => const SizedBox.shrink(),
        );
      } else {
        final localPath = coverUrl.startsWith('file://') ? coverUrl.substring(7) : coverUrl;
        coverWidget = Image.file(File(localPath), fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
      }
    }

    return Stack(
      children: [
        if (coverWidget != null)
          Positioned.fill(child: coverWidget),
        Positioned.fill(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(color: colorScheme.surface.withValues(alpha: 0.85)),
        ),
      ],
    );
  }
}
