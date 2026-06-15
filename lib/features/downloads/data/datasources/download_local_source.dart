import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_item_model.dart';
import '../models/queue_item_model.dart';
import '../models/download_progress_model.dart';

class DownloadLocalSource {
  static const _queueKey = 'download_queue';
  static const _historyKey = 'download_history';
  static const _progressKey = 'download_progress';

  Future<List<QueueItemModel>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_queueKey) ?? [];
    return data
        .map((e) => QueueItemModel.fromJson(jsonDecode(e)))
        .toList();
  }

  Future<void> saveQueue(List<QueueItemModel> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _queueKey, items.map((e) => jsonEncode(e.toJson())).toList());
  }

  Future<List<DownloadItemModel>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_historyKey) ?? [];
    return data
        .map((e) => DownloadItemModel.fromJson(jsonDecode(e)))
        .toList();
  }

  Future<void> saveHistory(List<DownloadItemModel> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _historyKey, items.map((e) => jsonEncode(e.toJson())).toList());
  }

  Future<void> addToHistory(DownloadItemModel item) async {
    final history = await getHistory();
    history.insert(0, item);
    await saveHistory(history);
  }

  Future<void> addToQueue(QueueItemModel item) async {
    final queue = await getQueue();
    queue.add(item);
    await saveQueue(queue);
  }

  Future<void> removeFromQueue(String itemId) async {
    final queue = await getQueue();
    queue.removeWhere((e) => e.id == itemId);
    await saveQueue(queue);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }

  Future<DownloadProgressModel?> getProgress(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('$_progressKey$itemId');
    if (data == null) return null;
    return DownloadProgressModel.fromJson(jsonDecode(data));
  }

  Future<void> saveProgress(DownloadProgressModel progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        '$_progressKey${progress.itemId}', jsonEncode(progress.toJson()));
  }

  Future<void> removeProgress(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_progressKey$itemId');
  }
}
