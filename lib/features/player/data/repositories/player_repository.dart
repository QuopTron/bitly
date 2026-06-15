import 'package:get_it/get_it.dart';
import '../../../../core/api/methods.dart';
import '../../../library/data/models/library_item_model.dart';

class PlayerRepository {
  final PlaybackMethods _api;

  PlayerRepository() : _api = GetIt.instance<PlaybackMethods>();

  Future<bool> play(LibraryItemModel track) async {
    return await _api.play({'id': track.id, 'title': track.title});
  }

  Future<bool> pause() async => _api.pause();
  Future<bool> resume() async => _api.resume();
  Future<bool> stop() async => _api.stop();
  Future<bool> next() async => _api.next();
  Future<bool> previous() async => _api.previous();
  Future<bool> seek(Duration position) async => _api.seek(Duration(milliseconds: position.inMilliseconds));

  Future<List<Map<String, dynamic>>> getQueue() async {
    return await _api.getQueue();
  }

  Future<bool> setQueue(List<Map<String, dynamic>> tracks) async {
    return await _api.setQueue(tracks);
  }

  Future<Map<String, dynamic>> getState() async {
    final queue = await _api.getQueue();
    return {'queue': queue, 'isPlaying': false};
  }
}
