import 'package:equatable/equatable.dart';
import '../../data/repositories/download_repository.dart';

class StartDownload extends Equatable {
  final DownloadRepository repository;

  const StartDownload(this.repository);

  Future<bool> call(String url, String quality) async {
    return await repository.startDownload(url, quality);
  }

  @override
  List<Object?> get props => [repository];
}
