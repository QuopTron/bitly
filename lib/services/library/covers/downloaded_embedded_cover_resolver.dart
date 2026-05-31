/// Resolvedor compartido de previsualizaciones de carátulas embebidas
/// en archivos de audio descargados. Mantiene una caché LRU limitada
/// a 180 entradas y refresca la extracción solo cuando el archivo
/// fuente ha cambiado.
library;

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:bitly/services/library/covers/embedded_cover_cache.dart';

class DownloadedEmbeddedCoverResolver {
  static final EmbeddedCoverCache _cache = EmbeddedCoverCache();

  static String cleanFilePath(String? filePath) {
    if (filePath == null) return '';
    if (filePath.startsWith('EXISTS:')) return filePath.substring(7);
    return filePath;
  }

  static Future<int?> readFileModTimeMillis(String? filePath) async {
    return readFileModTime(filePath);
  }

  static String? resolve(String? filePath, {VoidCallback? onChanged}) {
    final cleanPath = cleanFilePath(filePath);
    if (cleanPath.isEmpty) return null;

    if (_cache.isPendingRefresh(cleanPath)) {
      unawaited(_cache.ensureCover(cleanPath, forceRefresh: true, onChanged: onChanged));
    }

    final cached = _cache.get(cleanPath);
    if (cached != null) {
      _cache.put(cleanPath, cached);
      _cache.validatePreview(cleanPath);
      return cached.previewPath;
    }

    return null;
  }

  static Future<void> scheduleRefreshForPath(
    String? filePath, {
    int? beforeModTime,
    bool force = false,
    VoidCallback? onChanged,
  }) async {
    final cleanPath = cleanFilePath(filePath);
    if (cleanPath.isEmpty) return;

    if (!force) {
      if (beforeModTime == null) return;
      final afterModTime = await readFileModTimeMillis(cleanPath);
      if (afterModTime != null && afterModTime == beforeModTime) return;
    }

    _cache.markPendingRefresh(cleanPath);
    _cache.removeFailed(cleanPath);
    onChanged?.call();
  }

  static void invalidate(String? filePath) {
    final cleanPath = cleanFilePath(filePath);
    if (cleanPath.isEmpty) return;
    _cache.remove(cleanPath);
  }

  static void invalidatePathsNotIn(Set<String> validCleanPaths) {
    if (validCleanPaths.isEmpty) {
      _cache.removeAll();
      return;
    }
    _cache.removeStaleNotIn(validCleanPaths);
  }
}
