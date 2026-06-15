import 'package:get_it/get_it.dart';
import '../../data/repositories/player_repository.dart';

enum PlaybackAction { pause, resume, stop, next, previous }

class ControlPlayback {
  final PlayerRepository _repository;

  ControlPlayback() : _repository = GetIt.instance<PlayerRepository>();

  Future<void> call(PlaybackAction action) async {
    switch (action) {
      case PlaybackAction.pause:
        await _repository.pause();
      case PlaybackAction.resume:
        await _repository.resume();
      case PlaybackAction.stop:
        await _repository.stop();
      case PlaybackAction.next:
        await _repository.next();
      case PlaybackAction.previous:
        await _repository.previous();
    }
  }

  Future<void> seek(Duration position) async {
    await _repository.seek(position);
  }
}
