import 'package:get_it/get_it.dart';
import '../../data/repositories/player_repository.dart';
import '../../../library/data/models/library_item_model.dart';

class PlayTrack {
  final PlayerRepository _repository;

  PlayTrack() : _repository = GetIt.instance<PlayerRepository>();

  Future<void> call(LibraryItemModel track) async {
    await _repository.play(track);
  }
}
