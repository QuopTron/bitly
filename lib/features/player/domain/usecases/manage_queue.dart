import 'package:get_it/get_it.dart';
import '../../data/repositories/player_repository.dart';
import '../../../library/data/models/library_item_model.dart';

class ManageQueue {
  final PlayerRepository _repository;

  ManageQueue() : _repository = GetIt.instance<PlayerRepository>();

  Future<void> setQueue(List<LibraryItemModel> tracks) async {
    await _repository.setQueue(tracks.map((t) => t.toJson()).toList());
  }
}
