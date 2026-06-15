import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/player_bloc/player_bloc.dart';
import '../bloc/player_bloc/player_event.dart';
import '../bloc/player_bloc/player_state.dart';
import '../widgets/album_art.dart';
import '../widgets/play_controls.dart';
import '../widgets/progress_slider.dart';
import '../widgets/quality_selector.dart';
import '../widgets/audio_visualizer.dart';
import '../sheets/queue_sheet.dart';
import '../sheets/lyrics_sheet.dart';
import '../sheets/sleep_timer_sheet.dart';
import '../../domain/entities/playback_state.dart';

class PlayerPage extends StatelessWidget {
  final PlayerBloc playerBloc;

  const PlayerPage({super.key, required this.playerBloc});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerBloc, PlayerState>(
      bloc: playerBloc,
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            backgroundColor: const Color(0xFF121212),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Now Playing', style: TextStyle(color: Colors.white, fontSize: 14)),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
          body: Container(
            decoration: state.currentTrack?.coverPath != null
                ? BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(state.currentTrack!.coverPath!),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        const Color(0xFF121212).withValues(alpha: 0.85),
                        BlendMode.dstATop,
                      ),
                    ),
                  )
                : null,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    AlbumArt(coverPath: state.currentTrack?.coverPath),
                    const SizedBox(height: 32),
                    Text(
                      state.currentTrack?.title ?? 'No track',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.currentTrack?.artist ?? '',
                      style: TextStyle(color: Colors.grey[400], fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const AudioVisualizer(),
                    const Spacer(flex: 1),
                    ProgressSlider(
                      position: state.position,
                      duration: state.duration,
                      onSeek: (d) => playerBloc.add(SeekEvent(d)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            state.shuffle ? Icons.shuffle : Icons.shuffle_on_outlined,
                            color: state.shuffle ? const Color(0xFF1DB954) : Colors.grey,
                          ),
                          onPressed: () => playerBloc.add(SetShuffleEvent(!state.shuffle)),
                        ),
                        const SizedBox(width: 32),
                        IconButton(
                          icon: const Icon(Icons.skip_previous, color: Colors.white, size: 36),
                          onPressed: () => playerBloc.add(PreviousEvent()),
                        ),
                        PlayControls(
                          isPlaying: state.status == PlaybackStatus.playing,
                          onPlay: () => playerBloc.add(ResumeEvent()),
                          onPause: () => playerBloc.add(PauseEvent()),
                          onNext: () => playerBloc.add(NextEvent()),
                          onPrevious: () => playerBloc.add(PreviousEvent()),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next, color: Colors.white, size: 36),
                          onPressed: () => playerBloc.add(NextEvent()),
                        ),
                        const SizedBox(width: 32),
                        IconButton(
                          icon: Icon(
                            Icons.repeat,
                            color: state.repeatMode != RepeatMode.none
                                ? const Color(0xFF1DB954)
                                : Colors.grey,
                          ),
                          onPressed: () {
                            final modes = [RepeatMode.none, RepeatMode.all, RepeatMode.one];
                            final next = modes[(modes.indexOf(state.repeatMode) + 1) % 3];
                            playerBloc.add(SetRepeatEvent(next));
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const QualitySelector(),
                        IconButton(
                          icon: const Icon(Icons.queue_music, color: Colors.grey),
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            backgroundColor: const Color(0xFF1E1E1E),
                            builder: (_) => QueueSheet(
                              tracks: state.queue,
                              currentIndex: state.queueIndex,
                              onRemove: (i) => playerBloc.add(RemoveFromQueueEvent(i)),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.lyrics, color: Colors.grey),
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            backgroundColor: const Color(0xFF1E1E1E),
                            builder: (_) => const LyricsSheet(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.timer, color: Colors.grey),
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            backgroundColor: const Color(0xFF1E1E1E),
                            builder: (_) => const SleepTimerSheet(),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(flex: 1),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
