import 'package:equatable/equatable.dart';
import '../datasources/download_local_source.dart';
import '../datasources/download_remote_source.dart';
import '../models/download_item_model.dart';

class DownloadRepository extends Equatable {
  final DownloadLocalSource localSource;
  final DownloadRemoteSource remoteSource;

  const DownloadRepository(this.localSource, this.remoteSource);

  Future<void> addToQueue(DownloadItemModel item) async {
    await localSource.addToHistory(item);
  }

  Future<bool> startDownload(String url, String quality) async {
    return await remoteSource.startDownload(url, quality);
  }

  Future<bool> cancelDownload(String downloadId) async {
    final success = await remoteSource.cancelDownload(downloadId);
    if (success) {
      await localSource.removeProgress(downloadId);
    }
    return success;
  }

  Future<List<DownloadItemModel>> getHistory() async {
    return await localSource.getHistory();
  }



  Future<void> clearHistory() async {
    await localSource.clearHistory();
  }

  Future<void> updateItem(DownloadItemModel item) async {
    final history = await localSource.getHistory();
    final index = history.indexWhere((e) => e.id == item.id);
    if (index != -1) {
      history[index] = item;
      await localSource.saveHistory(history);
    }
  }

  @override
  List<Object?> get props => [localSource, remoteSource];
}
