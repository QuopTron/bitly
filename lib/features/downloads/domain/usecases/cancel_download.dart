import 'package:equatable/equatable.dart';
import '../../data/repositories/download_repository.dart';

class CancelDownload extends Equatable {
  final DownloadRepository repository;

  const CancelDownload(this.repository);

  Future<bool> call(String downloadId) async {
    return await repository.cancelDownload(downloadId);
  }

  @override
  List<Object?> get props => [repository];
}
