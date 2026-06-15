import '../../../../core/api/methods.dart';

class DownloadRemoteSource {
  final DownloadMethods _methods;

  const DownloadRemoteSource(this._methods);

  Future<bool> startDownload(String url, String quality) async {
    return await _methods.downloadByStrategy({
      'url': url,
      'quality': quality,
    });
  }

  Future<bool> cancelDownload(String downloadId) async {
    return await _methods.cancelDownload(downloadId);
  }

  Future<double> getDownloadProgress(String downloadId) async {
    return await _methods.getProgress(downloadId);
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    return await _methods.getHistory();
  }

  Future<bool> clearHistory() async {
    return await _methods.clearHistory();
  }
}
