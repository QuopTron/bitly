/// Servicio de reseteo de fábrica de la aplicación.
/// Limpia SharedPreferences, base de datos (vía Go backend o borrado directo),
/// secure storage, caché de carátulas, extensiones, carátulas de playlists,
/// caché general y opcionalmente los archivos de música descargados.
library;

import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitly/services/biblioteca/portadas/cover_cache_manager.dart';
import 'package:bitly/services/núcleo/platform_bridge.dart';
import 'package:bitly/utils/logger.dart';

final _log = AppLogger('AppResetService');

class AppResetService {
  static Future<void> resetEverything({bool deleteFiles = false}) async {
    _log.i('Starting full application reset (deleteFiles: $deleteFiles)');

    try {
      // 1. Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _log.d('SharedPreferences cleared');

      // 2. Reset database via Go backend
      try {
        await PlatformBridge.invoke('resetDatabase');
        _log.d('Database reset completed via Go backend');
      } catch (e) {
        _log.w('Could not reset database via Go backend: $e');
        // Fallback: Try to delete database file directly
        try {
          final docsDir = await getApplicationDocumentsDirectory();
          final dbPath = '${docsDir.path}/bitly_master.db';
          if (await File(dbPath).exists()) {
            await File(dbPath).delete();
            _log.d('Database file deleted directly: $dbPath');
          }
        } catch (fallbackError) {
          _log.w('Could not delete database file directly: $fallbackError');
        }
      }

      // 3. Clear FlutterSecureStorage (premium, activation code, Spotify client secret)
      const storage = FlutterSecureStorage();
      await storage.deleteAll();
      _log.d('FlutterSecureStorage cleared');

      // 4. Clear cover image cache
      try {
        await CoverCacheManager.clearCache();
        _log.d('Cover cache cleared');
      } catch (e) {
        _log.w('Failed to clear cover cache: $e');
      }

      // 5. Delete extensions
      try {
        final docDir = await getApplicationDocumentsDirectory();
        final extDir = Directory(p.join(docDir.path, 'extensions'));
        if (await extDir.exists()) {
          await extDir.delete(recursive: true);
          _log.d('Extensions directory deleted');
        }
        final extDataDir = Directory(p.join(docDir.path, 'extension_data'));
        if (await extDataDir.exists()) {
          await extDataDir.delete(recursive: true);
          _log.d('Extension data directory deleted');
        }
      } catch (e) {
        _log.w('Failed to delete extensions: $e');
      }

      // 6. Delete playlist covers
      try {
        final docDir = await getApplicationDocumentsDirectory();
        final coversDir = Directory(p.join(docDir.path, 'playlist_covers'));
        if (await coversDir.exists()) {
          await coversDir.delete(recursive: true);
          _log.d('Playlist covers directory deleted');
        }
      } catch (e) {
        _log.w('Failed to delete playlist covers: $e');
      }

      // 7. Clear app cache
      try {
        final cacheDir = await getApplicationCacheDirectory();
        if (await cacheDir.exists()) {
          await for (final entity in cacheDir.list(followLinks: false)) {
            try {
              await entity.delete(recursive: true);
            } catch (_) {}
          }
          _log.d('App cache cleared');
        }
      } catch (e) {
        _log.w('Failed to clear app cache: $e');
      }

      // 8. Delete physical files if requested
      if (deleteFiles) {
        await _deleteMusicDirectories();
      }
    } catch (e) {
      _log.e('Full reset failed: $e');
      rethrow;
    }
  }

  static Future<void> _deleteMusicDirectories() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final musicDir = Directory(p.join(docDir.path, 'SpotiFLAC'));
      if (await musicDir.exists()) {
        await musicDir.delete(recursive: true);
        _log.i('Music directory SpotiFLAC deleted');
      }

      final altMusicDir = Directory(p.join(docDir.path, 'Music'));
      if (await altMusicDir.exists()) {
        await altMusicDir.delete(recursive: true);
        _log.i('Music directory Music deleted');
      }
    } catch (e) {
      _log.w('Failed to delete music directories: $e');
    }
  }
}