/// Gestor de caché personalizado para imágenes de carátula.
/// Extiende [CacheManager] de flutter_cache_manager con ajuste automático
/// del límite de objetos según el uso actual del disco (200-400 objetos).
/// Proporciona inicialización diferida, estadísticas y limpieza completa
/// de la caché de imágenes en memoria y disco.
library;

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:bitly/services/biblioteca/portadas/cover_cache_stats.dart';

class CoverCacheManager {
  static const String _cacheKey = 'coverImageCache';
  static const Duration _maxCacheAge = Duration(days: 30);

  static CacheManager? _instance;
  static bool _initialized = false;
  static String? _cachePath;
  static int _maxCacheObjects = 200;

  static CacheManager get instance {
    if (!_initialized || _instance == null) {
      debugPrint('CoverCacheManager: not initialized, returning DefaultCacheManager');
      return DefaultCacheManager();
    }
    return _instance!;
  }

  static bool get isInitialized => _initialized && _instance != null;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final appDir = await getApplicationSupportDirectory();
      _cachePath = p.join(appDir.path, 'cover_cache');
      await Directory(_cachePath!).create(recursive: true);

      final stats = await _computeCacheStats();
      _maxCacheObjects = stats.optimalLimit;

      debugPrint('CoverCacheManager: init at $_cachePath, max=$_maxCacheObjects');

      _instance = _createManager(_cachePath!, _maxCacheObjects);
      _initialized = true;
    } catch (e) {
      debugPrint('CoverCacheManager: init failed: $e');
    }
  }

  static Future<({int optimalLimit, int fileCount})> _computeCacheStats() async {
    final path = _cachePath;
    if (path == null) return (optimalLimit: 200, fileCount: 0);

    final dir = Directory(path);
    if (!await dir.exists()) return (optimalLimit: 200, fileCount: 0);

    int fileCount = 0;
    int totalSize = 0;
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          fileCount++;
          totalSize += await entity.length();
        }
      }
    } catch (_) {}

    final optimalLimit = totalSize > 500 << 20 ? 400
        : totalSize > 100 << 20 ? 300
        : 200;
    return (optimalLimit: optimalLimit, fileCount: fileCount);
  }

  static Future<void> clearCache() async {
    if (!_initialized || _instance == null || _cachePath == null) {
      await initialize();
    }

    final cachePath = _cachePath;
    final instance = _instance;
    if (instance == null || cachePath == null) return;

    try {
      await instance.emptyCache();
    } catch (e) {
      debugPrint('CoverCacheManager: emptyCache failed: $e');
    }

    await _wipeDirectory(cachePath);

    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.clear();
    imageCache.clearLiveImages();

    instance.store.emptyMemoryCache();
    _instance = _createManager(cachePath, _maxCacheObjects);
    _initialized = true;
  }

  static Future<CacheStats> getStats() async {
    final path = _cachePath;
    if (path == null) return const CacheStats(fileCount: 0, totalSizeBytes: 0);

    final dir = Directory(path);
    if (!await dir.exists()) return const CacheStats(fileCount: 0, totalSizeBytes: 0);

    int fileCount = 0;
    int totalSize = 0;
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          fileCount++;
          totalSize += await entity.length();
        }
      }
    } catch (_) {}

    return CacheStats(fileCount: fileCount, totalSizeBytes: totalSize);
  }

  static CacheManager _createManager(String cachePath, int maxObjects) {
    return CacheManager(
      Config(
        _cacheKey,
        stalePeriod: _maxCacheAge,
        maxNrOfCacheObjects: maxObjects,
        repo: JsonCacheInfoRepository(path: cachePath),
        fileSystem: IOFileSystem(cachePath),
        fileService: HttpFileService(),
      ),
    );
  }

  static Future<void> _wipeDirectory(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      return;
    }

    try {
      await for (final entity in directory.list(followLinks: false)) {
        try {
          await entity.delete(recursive: true);
        } catch (_) {}
      }
    } catch (_) {}

    try {
      await directory.create(recursive: true);
    } catch (_) {}
  }
}
