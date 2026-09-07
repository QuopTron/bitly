import 'dart:async';

import 'package:audio_session/audio_session.dart';

import '../../injection.dart';
import 'player_cubit.dart';

/// Owns the platform audio session (Android audio focus / iOS AVAudioSession)
/// and pauses playback whenever another app takes the audio output.
///
/// `audio_service` powers the media notification but does NOT manage audio
/// focus, so without this another app (Spotify, a voice note, navigation,
/// another player…) would play on top of Bitly. Rules:
///
///  * Focus is requested the moment playback starts and released on pause.
///  * Permanent loss (another player took over) → pause, stay paused.
///  * Transient interruption (voice note, alarm, navigation) → duck volume,
///    resume when the focus comes back.
///  * Headphones unplugged (becoming noisy) → pause.
///
///  The player is a MUSIC PLAYER, so:
///  - Duck should lower volume, not pause (allows background music)
///  - Transient pauses resume quickly when focus returns
///  - Games that mute their own audio won't trigger a pause
///  - The player continues playing in background (second plane)
class AudioFocusService {
  AudioFocusService._();

  static final AudioFocusService instance = AudioFocusService._();

  bool _initialized = false;
  bool _pausedForInterruption = false;

  /// Starts listening to playback state + platform interruptions. Safe to call
  /// more than once.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final session = await AudioSession.instance;

      // Interruption stream: another app asked for the audio output.
      session.interruptionEventStream.listen(_onInterruption);

      // Headphones unplugged / BT disconnected while playing.
      session.becomingNoisyEventStream.listen((_) {
        if (_pausedForInterruption) return;
        _pausedForInterruption = true;
        sl<PlayerCubit>().pause();
      });

      // Mirror real playback state onto the session: focus is held while
      // playing and released on pause so other apps can take over cleanly.
      sl<PlayerCubit>().stream.listen((state) {
        unawaited(state.isPlaying
            ? session.setActive(true).catchError((_) => false)
            : session.setActive(false).catchError((_) => false));
      });
    } catch (_) {
      // audio_session unavailable on this platform — playback still works,
      // only the automatic pause-on-other-app behavior is skipped.
      _initialized = false;
    }
  }

  void _onInterruption(AudioInterruptionEvent event) {
    final player = sl<PlayerCubit>();
    if (event.begin) {
      switch (event.type) {
        case AudioInterruptionType.duck:
          // Duck: lower volume instead of pausing. The audio_session plugin
          // handles ducking automatically on Android, so we don't pause here.
          // This allows background music while the user interacts with other
          // apps that produce transient audio (games, navigation, etc.).
          break;
        case AudioInterruptionType.pause:
          // Transient pause (voice note, alarm, navigation). Pause quickly
          // and resume automatically when focus returns.
          if (!_pausedForInterruption && player.state.isPlaying) {
            _pausedForInterruption = true;
            player.pause();
          }
        case AudioInterruptionType.unknown:
          // Permanent loss — another player took over. Pause and do NOT
          // auto-resume (the user switched to the other app on purpose).
          _pausedForInterruption = false;
          if (player.state.isPlaying) player.pause();
      }
    } else {
      // Focus gained again. Resume if we were paused for a transient
      // interruption (not for permanent loss).
      final shouldResume = _pausedForInterruption &&
          event.type != AudioInterruptionType.unknown;
      _pausedForInterruption = false;
      if (shouldResume && !player.state.isPlaying) {
        // Small delay to let the other audio finish its transition.
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!player.state.isPlaying) player.play();
        });
      }
    }
  }
}
