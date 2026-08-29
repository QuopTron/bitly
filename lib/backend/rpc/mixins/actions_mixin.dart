import 'dart:convert';

import 'package:logger/logger.dart';

import '../backend_service.dart';

final _log = Logger();

/// Core actions mixin — like, download dispatch, progress, y size estimation van a Go.
mixin ActionsMixin on BackendService {
  @override
  Future<void> likeItem(String itemId, bool liked) async {
    try { await rpcCall('likeItem', {'item_id': itemId, 'liked': liked}); } catch (_) {}
  }

  @override
  Future<void> downloadItem(String itemId) async {
    try { await rpcCall('downloadItem', {'item_id': itemId}); } catch (_) {}
  }

  // ── Download progress & strategy (Go) ──

  @override
  Future<String> getAllDownloadProgress() async {
    try { return await rpcCall('getAllDownloadProgress') as String; } catch (_) { return ''; }
  }
  @override
  Future<void> cancelDownload(String itemId) async {
    try { await rpcCall('cancelDownload', {'item_id': itemId}); } catch (_) {}
  }
  @override
  Future<dynamic> downloadByStrategy(String json) async {
    try {
      return await rpcCall('downloadByStrategy', {'request': json});
    } catch (_) {
      return null;
    }
  }
  @override
  Future<void> initItemProgress(String itemId, {String trackName = '', String artistName = ''}) async {
    try {
      await rpcCall('initItemProgress', {
        'item_id': itemId, 'track_name': trackName, 'artist_name': artistName,
      });
    } catch (_) {}
  }
  @override
  Future<String> estimateTrackFileSize(int durationMs, String quality) async {
    try {
      return await rpcCall('estimateTrackFileSize', {
        'duration_ms': durationMs, 'quality': quality,
      }) as String;
    } catch (_) { return '{}'; }
  }

  // ── Config sync ─────────────────────────────────────────────────────

  @override
  Future<void> syncDownloadDir(String path) async {
    try { await rpcCall('setDownloadDirectory', {'path': path}); } catch (_) {}
  }

  @override
  Future<void> syncBackendConfig({String? mode, int? streamCacheMaxMb, int? downloadConcurrency, int? streamChunkSize}) async {
    try {
      final params = <String, dynamic>{};
      if (mode != null) params['mode'] = mode;
      if (streamCacheMaxMb != null) params['stream_cache_max_mb'] = streamCacheMaxMb;
      if (downloadConcurrency != null) params['download_concurrency'] = downloadConcurrency;
      if (streamChunkSize != null) params['stream_chunk_size'] = streamChunkSize;
      if (params.isNotEmpty) await rpcCall('setBackendConfig', params);
    } catch (_) {}
  }

  @override
  Future<void> syncDownloadProviderPriority(List<String> providers) async {
    try {
      await rpcCall('setDownloadProviderPriority', {'providers': providers});
    } catch (_) {}
  }

  // ── Signed Session ───────────────────────────────────────────────────

  @override
  Future<String> getPendingVerificationUrl(String extensionId) async {
    try {
      final result = await rpcCall('getPendingVerificationUrl', {'extension_id': extensionId});
      return _extractAuthUrl(result);
    } catch (_) { return ''; }
  }

  @override
  Future<String> triggerExtensionVerification(String extensionId) async {
    try {
      final result = await rpcCall('triggerExtensionVerification', {'extension_id': extensionId});
      return _extractAuthUrl(result);
    } catch (_) { return ''; }
  }

  /// Extracts auth_url from a Go signed-session response. Returns empty
  /// string when the extension doesn't need verification (not loaded,
  /// signedSession not configured, healthy session). Throws when the
  /// extension needs verification but the URL couldn't be obtained
  /// (e.g. bootstrap network failure).
  String _extractAuthUrl(dynamic result) {
    Map<String, dynamic>? map;
    if (result is Map) {
      map = result.cast<String, dynamic>();
    } else if (result is String && result.isNotEmpty) {
      final decoded = jsonDecode(result);
      if (decoded is Map) map = decoded.cast<String, dynamic>();
    }
    if (map == null) return '';
    // Errors that mean "no verification needed" → return empty.
    final error = map['error'] as String?;
    if (error != null) {
      final lower = error.toLowerCase();
      if (lower.contains('not configured') || lower.contains('no cargada')) {
        return ''; // extension doesn't have signed session support
      }
      // Other errors (bootstrap failure, network, etc.) → throw so the
      // caller can show the verification as "failed" and retry.
      throw Exception(error);
    }
    return map['auth_url'] as String? ?? '';
  }

  @override
  Future<SignedSessionStatus> getSignedSessionStatus(String extensionId) async {
    try {
      final result = await rpcCall('getSignedSessionStatus', {'extension_id': extensionId});
      if (result is Map) {
        return SignedSessionStatus.fromJson(Map<String, dynamic>.from(result));
      }
      if (result is String && result.isNotEmpty) {
        final decoded = jsonDecode(result);
        if (decoded is Map) return SignedSessionStatus.fromJson(Map<String, dynamic>.from(decoded));
      }
      return const SignedSessionStatus();
    } catch (e) {
      _log.w('[actions] getSignedSessionStatus error for $extensionId: $e');
      return const SignedSessionStatus();
    }
  }

  @override
  Future<bool> completeSignedSessionGrant(String extensionId, String grantCode) async {
    try {
      final result = await rpcCall('completeSignedSessionGrant', {
        'extension_id': extensionId,
        'grant_code': grantCode,
      });
      bool ok = false;
      String? error;
      if (result is Map) {
        ok = result['success'] == true;
        error = result['error'] as String?;
      } else if (result is String && result.isNotEmpty) {
        final decoded = jsonDecode(result);
        if (decoded is Map) {
          ok = decoded['success'] == true;
          error = decoded['error'] as String?;
        }
      }
      if (!ok) {
        _log.w('[actions] completeSignedSessionGrant failed for '
            '$extensionId: $error');
      }
      return ok;
    } catch (e) {
      _log.e('[actions] completeSignedSessionGrant error for $extensionId: $e');
      return false;
    }
  }

}


