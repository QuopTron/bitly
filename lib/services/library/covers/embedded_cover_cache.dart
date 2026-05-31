/// Caché LRU interno para carátulas extraídas de archivos de audio.
/// Mantiene un límite de 180 entradas, valida que los previsualizadores
/// temporales sigan existiendo y limpia automáticamente las entradas
/// más antiguas cuando se excede el límite.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/utils/file_access.dart';

String cleanFilePathHelper(String? filePath) {
  if (filePath == null) return '';
  if (filePath.startsWith('EXISTS:')) return filePath.substring(7);
  return filePath;
}

class EmbeddedCoverCacheEntry {
  final String previewPath;
  final int? sourceModTimeMillis;

  const EmbeddedCoverCacheEntry({
    required this.previewPath,
    this.sourceModTimeMillis,
  });
}

class EmbeddedCoverCache {
  static const int maxCacheEntries = 180;

  final LinkedHashMap<String, EmbeddedCoverCacheEntry> _cache =
      LinkedHashMap<String, EmbeddedCoverCacheEntry>();
  final Set<String> _pendingExtract = <String>{};
  final Set<String> _pendingRefresh = <String>{};
  final Set<String> _pendingPreviewValidation = <String>{};
  final Set<String> _failedExtract = <String>{};

  EmbeddedCoverCacheEntry? get(String key) => _cache[key];
  bool isFailed(String key) => _failedExtract.contains(key);
  bool isPendingExtract(String key) => _pendingExtract.contains(key);
  bool isPendingRefresh(String key) => _pendingRefresh.contains(key);
  void markPendingRefresh(String key) => _pendingRefresh.add(key);
  void addPendingExtract(String key) => _pendingExtract.add(key);
  void removePendingExtract(String key) => _pendingExtract.remove(key);
  void removeFailed(String key) => _failedExtract.remove(key);

  void put(String key, EmbeddedCoverCacheEntry entry) {
    _cache
      ..remove(key)
      ..[key] = entry;
    _trimIfNeeded();
  }

  EmbeddedCoverCacheEntry? remove(String key) {
    _pendingExtract.remove(key);
    _pendingRefresh.remove(key);
    _pendingPreviewValidation.remove(key);
    _failedExtract.remove(key);
    final removed = _cache.remove(key);
    return removed;
  }

  void removeAll() {
    for (final key in _cache.keys.toList(growable: false)) {
      remove(key);
    }
  }

  void removeStaleNotIn(Set<String> validKeys) {
    final stale = _cache.keys.where((k) => !validKeys.contains(k)).toList();
    for (final key in stale) {
      remove(key);
    }
  }

  Iterable<String> get keys => _cache.keys;

  bool validatePreview(String cleanPath) {
    if (_pendingPreviewValidation.contains(cleanPath)) return false;
    _pendingPreviewValidation.add(cleanPath);
    Future.microtask(() async {
      try {
        final entry = _cache[cleanPath];
        if (entry == null) return;
        final exists = await fileExists(entry.previewPath);
        if (!exists) {
          final latest = _cache[cleanPath];
          if (latest != null && latest.previewPath == entry.previewPath) {
            _cache.remove(cleanPath);
            _failedExtract.remove(cleanPath);
          }
          _scheduleCleanup(entry.previewPath);
        }
      } finally {
        _pendingPreviewValidation.remove(cleanPath);
      }
    });
    return true;
  }

  Future<void> ensureCover(
    String cleanPath, {
    bool forceRefresh = false,
    int? knownModTime,
    VoidCallback? onChanged,
  }) async {
    if (cleanPath.isEmpty) return;
    if (_pendingExtract.contains(cleanPath)) return;
    if (!forceRefresh && _cache.containsKey(cleanPath)) return;
    if (!forceRefresh && _failedExtract.contains(cleanPath)) return;

    _pendingExtract.add(cleanPath);
    String? outputPath;
    try {
      final modTime = knownModTime ?? await readFileModTime(cleanPath);
      final tempDir = await Directory.systemTemp.createTemp('download_cover_preview_');
      outputPath = '${tempDir.path}${Platform.pathSeparator}cover_preview.jpg';
      final result = await PlatformBridge.extractCoverToFile(cleanPath, outputPath);

      if (result['error'] != null || !await File(outputPath).exists()) {
        _failedExtract.add(cleanPath);
        _scheduleCleanup(outputPath);
        return;
      }

      final previous = _cache[cleanPath];
      put(cleanPath, EmbeddedCoverCacheEntry(
        previewPath: outputPath,
        sourceModTimeMillis: modTime,
      ));
      _failedExtract.remove(cleanPath);

      if (previous != null && previous.previewPath != outputPath) {
        _scheduleCleanup(previous.previewPath);
      }
      onChanged?.call();
    } catch (_) {
      _failedExtract.add(cleanPath);
      _scheduleCleanup(outputPath);
    } finally {
      _pendingExtract.remove(cleanPath);
    }
  }

  void _trimIfNeeded() {
    while (_cache.length > maxCacheEntries) {
      final oldestKey = _cache.keys.first;
      final removed = _cache.remove(oldestKey);
      if (removed != null) _scheduleCleanup(removed.previewPath);
      _pendingExtract.remove(oldestKey);
      _pendingRefresh.remove(oldestKey);
      _pendingPreviewValidation.remove(oldestKey);
      _failedExtract.remove(oldestKey);
    }
  }

  void _scheduleCleanup(String? coverPath) {
    unawaited(_doCleanup(coverPath));
  }

  Future<void> _doCleanup(String? coverPath) async {
    if (coverPath == null || coverPath.isEmpty) return;
    try {
      final file = File(coverPath);
      try { await file.delete(); } catch (_) {}
      try { await file.parent.delete(recursive: true); } catch (_) {}
    } catch (_) {}
  }
}

Future<int?> readFileModTime(String? filePath) async {
  final cleanPath = cleanFilePathHelper(filePath);
  if (cleanPath.isEmpty) return null;

  if (isContentUri(cleanPath)) {
    try {
      final modTimes = await PlatformBridge.getSafFileModTimes([cleanPath]);
      return modTimes[cleanPath];
    } catch (_) {
      return null;
    }
  }

  try {
    final stat = await File(cleanPath).stat();
    return stat.modified.millisecondsSinceEpoch;
  } catch (_) {
    return null;
  }
}

bool isContentUri(String path) {
  return path.startsWith('content://');
}
