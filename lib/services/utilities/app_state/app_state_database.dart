/// Puente singleton hacia el backend Go para persistencia del estado de la app.
/// Gestiona operaciones de cola de descarga (guardar, cargar, pendientes,
/// reemplazar). Las operaciones de acceso reciente y descargas ocultas
/// se encuentran en [AppStateRecentAccess].
library;

import 'dart:convert';
import 'package:bitly/services/utilities/database_utils.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/utils/logger.dart';

final _appLog = AppLogger('AppStateDb');

class AppStateDatabase {
  static final AppStateDatabase instance = AppStateDatabase._init();
  AppStateDatabase._init();

  Future<void> saveQueueItems(List<Map<String, dynamic>> items) async {
    try {
      await PlatformBridge.invoke('saveDownloadQueue', {'items': jsonEncode(items)});
    } catch (e) {
      _appLog.w('Go saveDownloadQueue failed: $e');
      throw DatabaseUtils.dbError();
    }
  }

  Future<List<Map<String, dynamic>>> loadQueueItems() async {
    try {
      final result = await PlatformBridge.invoke('loadDownloadQueue');
      if (result is String && result.isNotEmpty) {
        final decoded = jsonDecode(result);
        if (decoded is List) return decoded.cast<Map<String, dynamic>>();
      }
      _appLog.w('Go loadDownloadQueue returned empty result');
      return [];
    } catch (e) {
      _appLog.w('Go loadDownloadQueue failed: $e');
      throw DatabaseUtils.dbError();
    }
  }

  Future<List<Map<String, dynamic>>> getPendingDownloadQueueRows() async {
    try {
      final result = await PlatformBridge.invoke('getPendingDownloadQueueRows');
      if (result is String && result.isNotEmpty) {
        final decoded = jsonDecode(result);
        if (decoded is List) return decoded.cast<Map<String, dynamic>>();
      }
      _appLog.w('Go getPendingDownloadQueueRows returned empty result');
      return [];
    } catch (e) {
      _appLog.w('Go getPendingDownloadQueueRows failed: $e');
      throw DatabaseUtils.dbError();
    }
  }

  Future<void> replacePendingDownloadQueueRows(List<Map<String, dynamic>> rows) async {
    try {
      await PlatformBridge.invoke('replacePendingDownloadQueueRows', {'rows': jsonEncode(rows)});
    } catch (e) {
      _appLog.w('Go replacePendingDownloadQueueRows failed: $e');
      throw DatabaseUtils.dbError();
    }
  }
}
