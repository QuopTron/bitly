import 'package:equatable/equatable.dart';
import '../../data/repositories/download_repository.dart';

class RetryDownload extends Equatable {
  final DownloadRepository repository;

  const RetryDownload(this.repository);

  Future<bool> call(String downloadId) async {
    // Retry logic would re-add to queue
    return false;
  }

  @override
  List<Object?> get props => [repository];
}
