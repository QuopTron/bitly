import 'package:equatable/equatable.dart';
import '../../data/repositories/download_repository.dart';
import '../../data/models/download_item_model.dart';

class GetHistory extends Equatable {
  final DownloadRepository repository;

  const GetHistory(this.repository);

  Future<List<DownloadItemModel>> call() async {
    return await repository.getHistory();
  }

  @override
  List<Object?> get props => [repository];
}
