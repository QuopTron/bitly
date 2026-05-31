/// Operaciones de acceso reciente y descargas ocultas del estado de la app.
/// Delega en [PlatformBridge] para persistir vía el backend Go.
/// Contiene métodos para upsert, consulta, borrado de filas de acceso
/// reciente y gestión de IDs de descarga ocultos.
library;

import 'dart:convert';
import 'package:bitly/services/utilidades/database_utils.dart';
import 'package:bitly/services/núcleo/platform_bridge.dart';
import 'package:bitly/utils/logger.dart';

final _accessLog = AppLogger('AppStateRecent');

class AppStateRecentAccess {
  static final AppStateRecentAccess instance = AppStateRecentAccess._init();
  AppStateRecentAccess._init();

  Future<void> addRecentAccess(Map<String, dynamic> item) async {
    return upsertRecentAccessRow(
      uniqueKey: item['key'] as String,
      itemJson: jsonEncode(item),
    );
  }

  Future<void> upsertRecentAccessRow({
    required String uniqueKey,
    required String itemJson,
    String? accessedAt,
  }) async {
    try {
      await PlatformBridge.invoke('upsertRecentAccessRow', {
        'key': uniqueKey,
        'json': itemJson,
        'accessed_at': accessedAt ?? DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _accessLog.w('Go upsertRecentAccessRow failed: $e');
      throw DatabaseUtils.dbError();
    }
  }

  Future<List<Map<String, dynamic>>> getRecentAccessRows({int limit = 50}) async {
    try {
      final result = await PlatformBridge.invoke('getRecentAccessRows', {'limit': limit});
      if (result is String && result.isNotEmpty) {
        final decoded = jsonDecode(result);
        if (decoded is List) return decoded.cast<Map<String, dynamic>>();
      }
      _accessLog.w('Go getRecentAccessRows returned empty result');
      return [];
    } catch (e) {
      _accessLog.w('Go getRecentAccessRows failed: $e');
      return [];
    }
  }

  Future<void> deleteRecentAccessRow(String key) async {
    try {
      await PlatformBridge.invoke('deleteRecentAccessRow', {'key': key});
    } catch (e) {
      _accessLog.w('Go deleteRecentAccessRow failed: $e');
      throw DatabaseUtils.dbError();
    }
  }

  Future<void> clearRecentAccessRows() async {
    try {
      await PlatformBridge.invoke('clearRecentAccessRows');
    } catch (e) {
      _accessLog.w('Go clearRecentAccessRows failed: $e');
      throw DatabaseUtils.dbError();
    }
  }

  Future<Set<String>> getHiddenRecentDownloadIds() async {
    try {
      final result = await PlatformBridge.invoke('getHiddenRecentDownloadIds');
      if (result is String && result.isNotEmpty) {
        final decoded = jsonDecode(result);
        if (decoded is List) return decoded.cast<String>().toSet();
      }
      _accessLog.w('Go getHiddenRecentDownloadIds returned empty result');
      return {};
    } catch (e) {
      _accessLog.w('Go getHiddenRecentDownloadIds failed: $e');
      return {};
    }
  }

  Future<void> addHiddenRecentDownloadId(String downloadId) async {
    try {
      await PlatformBridge.invoke('addHiddenRecentDownloadId', {'download_id': downloadId});
    } catch (e) {
      _accessLog.w('Go addHiddenRecentDownloadId failed: $e');
      throw DatabaseUtils.dbError();
    }
  }

  Future<void> clearHiddenRecentDownloadIds() async {
    try {
      await PlatformBridge.invoke('clearHiddenRecentDownloadIds');
    } catch (e) {
      _accessLog.w('Go clearHiddenRecentDownloadIds failed: $e');
      throw DatabaseUtils.dbError();
    }
  }
}
