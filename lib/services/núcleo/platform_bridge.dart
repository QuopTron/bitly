// Thin Dart wrapper over the Go backend's JSON-RPC method channel.
//
// All calls go through [invoke] which dispatches either to
// [MethodChannel] (mobile) or HTTP POST (desktop).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitly/constants/app_info.dart';
import 'package:bitly/services/descargas/download_request_payload.dart';
import 'package:bitly/services/descargas/download_request_extension.dart';
import 'package:bitly/services/núcleo/platform_bridge_models.dart';
import 'package:bitly/services/núcleo/puente_decodificador.dart';
import 'package:bitly/utils/logger.dart';

export 'package:bitly/services/núcleo/platform_bridge_models.dart';
export 'package:bitly/services/núcleo/puente_decodificador.dart';

final _log = AppLogger('PlatformBridge');

class PlatformBridge {
  static const _mobileChannel = MethodChannel('com.zarz.spotiflac/backend');
  static bool _useHttpBackend = false;
  static int _backendPort = 55009;

  static int getBackendPort() => _backendPort;

  static Future<dynamic> invoke(String method, [dynamic args]) async {
    return _invoke(method, args);
  }

  static Future<dynamic> _invoke(String method, [dynamic args]) async {
    if (_useHttpBackend) {
      return _httpInvoke(method, args);
    }
    return _mobileChannel.invokeMethod(method, args);
  }

  static Future<dynamic> _httpInvoke(String method, dynamic args) async {
    try {
      Map<String, dynamic> params;
      if (args is Map<String, dynamic>) {
        params = args;
      } else if (args is String) {
        params = {'request': args};
      } else {
        params = {};
      }
      final body = jsonEncode({'method': method, 'params': params});
      final response = await http
          .post(
            Uri.parse('http://127.0.0.1:$_backendPort/rpc'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['error'] != null) throw Exception(decoded['error']);
      return decoded['result'];
    } catch (e) {
      _log.e('HTTP RPC $method failed: $e');
      rethrow;
    }
  }

  static Future<void> initDesktopBackend() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    if (_useHttpBackend) return;

    _useHttpBackend = true;

    // Kill any orphaned backend instances from previous runs
    _killOrphanedBackends();

    var exeName = _findBackendExe();
    if (exeName == null) {
      _log.w('Backend executable not found, attempting to build...');
      exeName = await _tryBuildBackend();
      if (exeName == null) {
        _log.e('Could not find or build Go backend');
        return;
      }
    }

    for (int port = _backendPort; port < _backendPort + 20; port++) {
      try {
        final exePath = p.isAbsolute(exeName) ? exeName : p.absolute(exeName);
        final process = await Process.start(
          exePath,
          [],
          workingDirectory: p.dirname(exePath),
          environment: {'PORT': port.toString()},
        );

        final exitCodeOrTimeout = await Future.any([
          process.exitCode.then((code) => code),
          Future.delayed(const Duration(milliseconds: 800), () => null),
        ]);

        if (exitCodeOrTimeout != null) {
          _log.w(
            'Backend on port $port exited with code $exitCodeOrTimeout, trying next',
          );
          continue;
        }

        _backendPort = port;
        _log.i('Backend started on port $port (PID: ${process.pid})');

        process.stderr.listen((data) {
          final msg = utf8.decode(data);
          if (msg.contains('bind:') || msg.contains('in use')) {
            _log.w('Backend port conflict: $msg');
          } else {
            _log.w('Backend stderr: $msg');
          }
        });
        process.stdout.listen((data) {
          _log.d('Backend stdout: ${utf8.decode(data)}');
        });

        process.exitCode.then((code) {
          _log.i('Backend exited with code: $code');
        });
        return;
      } catch (e) {
        _log.w('Failed to start backend on port $port: $e');
      }
    }
    _log.e('Could not start backend on any port');
  }

  static void _killOrphanedBackends() {
    if (Platform.isWindows) {
      for (final exe in ['bitly-backend.exe']) {
        try {
          final result = Process.runSync('taskkill', ['/f', '/im', exe]);
          if (result.exitCode == 0) {
            _log.i('Killed orphaned backend instance: $exe');
          }
        } catch (_) {}
      }
    } else if (Platform.isLinux || Platform.isMacOS) {
      try {
        Process.runSync('pkill', ['-f', 'bitly-backend']);
      } catch (_) {}
    }
  }

  static String? _findBackendExe() {
    final candidates = ['bitly-backend'];
    final searchDirs = <String>{
      Directory.current.path,
      File(Platform.resolvedExecutable).parent.path,
    };
    try {
      final scriptPath = Platform.script.toFilePath();
      searchDirs.add(File(scriptPath).parent.path);
    } catch (_) {}

    if (Platform.isWindows) {
      searchDirs.add(p.join(Directory.current.path, 'bin'));
      searchDirs.add(
        p.join(File(Platform.resolvedExecutable).parent.path, 'bin'),
      );
    }

    for (final name in candidates) {
      final withExt = Platform.isWindows ? '$name.exe' : name;
      for (final dir in searchDirs) {
        final candidatePath = p.join(dir, withExt);
        if (File(candidatePath).existsSync()) return candidatePath;
      }
      if (File(withExt).existsSync()) return withExt;
    }
    return null;
  }

  static Future<String?> _findGoExecutable() async {
    final goExeName = Platform.isWindows ? 'go.exe' : 'go';
    try {
      final result = await Process.run(goExeName, ['version']);
      if (result.exitCode == 0) return goExeName;
    } catch (_) {}

    final goRoot = Platform.environment['GOROOT'];
    if (goRoot != null && goRoot.isNotEmpty) {
      final goExePath =
          Platform.isWindows
              ? p.join(goRoot, 'bin', 'go.exe')
              : p.join(goRoot, 'bin', 'go');
      if (File(goExePath).existsSync()) return goExePath;
    }
    return null;
  }

  static Future<String?> _tryBuildBackend() async {
    final goExe = await _findGoExecutable();
    if (goExe == null) {
      _log.w('Go executable not found');
      return null;
    }

    final searchDirs = <String>{
      Directory.current.path,
      File(Platform.resolvedExecutable).parent.path,
    };
    try {
      final scriptPath = Platform.script.toFilePath();
      searchDirs.add(File(scriptPath).parent.path);
    } catch (_) {}
    String? projectRoot;
    for (final base in searchDirs) {
      final candidate = p.join(base, 'go_backend_bitly');
      if (Directory(candidate).existsSync()) {
        projectRoot = candidate;
        break;
      }
    }

    if (projectRoot == null) {
      _log.w('Go source directory not found in current runtime paths');
      return null;
    }

    final outputName =
        Platform.isWindows ? 'bitly-backend.exe' : 'bitly-backend';
    final outputPath = p.join(p.dirname(projectRoot), outputName);

    try {
      _log.i('Building Go backend from $projectRoot...');
      final result = await Process.run(
        goExe,
        ['build', '-o', outputPath, './cmd/server'],
        workingDirectory: projectRoot,
        environment: {'GONOSUMCHECK': '*', 'CGO_ENABLED': '0'},
      );
      if (result.exitCode != 0) {
        _log.e('Go build failed: ${result.stderr}');
        return null;
      }
      _log.i('Go backend built successfully');
      return outputPath;
    } catch (e) {
      _log.e('Failed to build Go backend: $e');
      return null;
    }
  }

  static const _metadataCacheTtl = Duration(minutes: 10);
  static const _availabilityCacheTtl = Duration(minutes: 10);
  static const _bridgeCacheMaxEntries = 50;
  static const _metadataPersistentCacheKey = 'bridge_metadata_lookup_cache_v1';
  static const _availabilityPersistentCacheKey =
      'bridge_availability_lookup_cache_v1';
  static const _downloadProgressEvents = EventChannel(
    'com.zarz.spotiflac/download_progress_stream',
  );
  static const _libraryScanProgressEvents = EventChannel(
    'com.zarz.spotiflac/library_scan_progress_stream',
  );
  static final Map<String, BridgeCacheEntry> _metadataCache = {};
  static final Map<String, BridgeCacheEntry> _availabilityCache = {};
  static final Map<String, Future<Map<String, dynamic>>> _metadataInFlight = {};
  static final Map<String, Future<Map<String, dynamic>>> _availabilityInFlight =
      {};
  static final Map<String, BridgeInFlight<List<Map<String, dynamic>>>>
  _customSearchInFlight = {};
  static final Map<String, BridgeInFlight<Map<String, dynamic>?>>
  _homeFeedInFlight = {};
  static Future<void>? _persistentLookupCacheLoadFuture;
  static int _lookupCacheGeneration = 0;
  static int _extensionRequestSequence = 0;

  static bool get supportsCoreBackend => true;

  static bool get supportsExtensionSystem => true;

  static Future<Map<String, dynamic>> checkAvailability(
    String spotifyId,
    String isrc,
  ) async {
    final cacheKey = _availabilityCacheKey(spotifyId, isrc);
    if (cacheKey.isEmpty) {
      _log.d('checkAvailability: $spotifyId (ISRC: $isrc)');
      final result = await _invoke('checkAvailability', {
        'spotify_id': spotifyId,
        'isrc': isrc,
      });
      return decodeRequiredMapResult(result, 'checkAvailability');
    }
    await _ensurePersistentLookupCachesLoaded();
    final cached = _getCachedMap(_availabilityCache, cacheKey);
    if (cached != null) return cached;

    final inFlight = _availabilityInFlight[cacheKey];
    if (inFlight != null) return copyStringMap(await inFlight);

    final generation = _lookupCacheGeneration;
    final future = _invokeCachedMap(
      cacheKey,
      _availabilityCache,
      () async {
        _log.d('checkAvailability: $spotifyId (ISRC: $isrc)');
        final result = await _invoke('checkAvailability', {
          'spotify_id': spotifyId,
          'isrc': isrc,
        });
        return decodeRequiredMapResult(result, 'checkAvailability');
      },
      _availabilityCacheTtl,
      generation,
      _availabilityPersistentCacheKey,
    );
    _availabilityInFlight[cacheKey] = future;
    try {
      return copyStringMap(await future);
    } finally {
      _availabilityInFlight.remove(cacheKey);
    }
  }

  static Future<Map<String, dynamic>> _invokeCachedMap(
    String key,
    Map<String, BridgeCacheEntry> cache,
    Future<Map<String, dynamic>> Function() loader,
    Duration ttl,
    int generation,
    String persistentCacheKey,
  ) async {
    final value = await loader();
    if (generation == _lookupCacheGeneration) {
      _putCachedMap(cache, key, value, ttl, persistentCacheKey);
    }
    return copyStringMap(value);
  }

  static String _availabilityCacheKey(String spotifyId, String isrc) {
    final normalizedIsrc = isrc.trim().toUpperCase();
    if (normalizedIsrc.isNotEmpty) {
      return 'isrc:$normalizedIsrc';
    }
    final normalizedSpotifyId = spotifyId.trim();
    if (normalizedSpotifyId.isEmpty) return '';
    return 'spotify:$normalizedSpotifyId';
  }

  static String _providerMetadataCacheKey(
    String providerId,
    String resourceType,
    String resourceId,
  ) {
    return [
      providerId.trim().toLowerCase(),
      resourceType.trim().toLowerCase(),
      resourceId.trim(),
    ].join(':');
  }

  static Map<String, dynamic>? _getCachedMap(
    Map<String, BridgeCacheEntry> cache,
    String key,
  ) {
    _pruneExpiredBridgeCache(cache);
    final entry = cache[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      cache.remove(key);
      return null;
    }
    return copyStringMap(entry.value);
  }

  static void _putCachedMap(
    Map<String, BridgeCacheEntry> cache,
    String key,
    Map<String, dynamic> value,
    Duration ttl,
    String persistentCacheKey,
  ) {
    _pruneExpiredBridgeCache(cache);
    while (cache.length >= _bridgeCacheMaxEntries && cache.isNotEmpty) {
      cache.remove(cache.keys.first);
    }
    cache[key] = BridgeCacheEntry(
      value: copyStringMap(value),
      expiresAt: DateTime.now().add(ttl),
    );
    unawaited(
      _persistLookupCache(cache, persistentCacheKey, _lookupCacheGeneration),
    );
  }

  static void _pruneExpiredBridgeCache(Map<String, BridgeCacheEntry> cache) {
    if (cache.isEmpty) return;
    final now = DateTime.now();
    cache.removeWhere((_, entry) => now.isAfter(entry.expiresAt));
  }

  static Future<void> _ensurePersistentLookupCachesLoaded() {
    return _persistentLookupCacheLoadFuture ??= _loadPersistentLookupCaches(
      _lookupCacheGeneration,
    );
  }

  static Future<void> _loadPersistentLookupCaches(int generation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _lookupCacheGeneration) return;
      _restorePersistentCache(
        prefs,
        _metadataPersistentCacheKey,
        _metadataCache,
      );
      _restorePersistentCache(
        prefs,
        _availabilityPersistentCacheKey,
        _availabilityCache,
      );
    } catch (e) {
      _log.w('Failed to load bridge lookup cache: $e');
    }
  }

  static void _restorePersistentCache(
    SharedPreferences prefs,
    String prefsKey,
    Map<String, BridgeCacheEntry> target,
  ) {
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return;

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;

    final now = DateTime.now();
    for (final entry in decoded.entries) {
      if (target.length >= _bridgeCacheMaxEntries) break;
      final key = entry.key.toString();
      final rawEntry = entry.value;
      if (key.isEmpty || rawEntry is! Map) continue;

      final expiresAtMs = rawEntry['expires_at'];
      final value = rawEntry['value'];
      if (expiresAtMs is! int || value is! Map) continue;

      final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtMs);
      if (!expiresAt.isAfter(now)) continue;

      target[key] = BridgeCacheEntry(
        value: copyStringMap(Map<String, dynamic>.from(value)),
        expiresAt: expiresAt,
      );
    }
  }

  static Future<void> _persistLookupCache(
    Map<String, BridgeCacheEntry> cache,
    String prefsKey,
    int generation,
  ) async {
    try {
      _pruneExpiredBridgeCache(cache);
      final data = <String, dynamic>{
        for (final entry in cache.entries)
          entry.key: {
            'expires_at': entry.value.expiresAt.millisecondsSinceEpoch,
            'value': entry.value.value,
          },
      };
      final prefs = await SharedPreferences.getInstance();
      if (generation != _lookupCacheGeneration) return;
      await prefs.setString(prefsKey, jsonEncode(data));
    } catch (e) {
      _log.w('Failed to persist bridge lookup cache: $e');
    }
  }

  static Future<void> _clearPersistentLookupCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_metadataPersistentCacheKey);
      await prefs.remove(_availabilityPersistentCacheKey);
    } catch (e) {
      _log.w('Failed to clear bridge lookup cache: $e');
    }
  }

  static Future<void> _clearLookupCaches() async {
    _lookupCacheGeneration++;
    _persistentLookupCacheLoadFuture = null;
    _metadataCache.clear();
    _availabilityCache.clear();
    _metadataInFlight.clear();
    _availabilityInFlight.clear();
    for (final inFlight in _customSearchInFlight.values) {
      _cancelExtensionRequestUnawaited(inFlight.requestId);
    }
    for (final inFlight in _homeFeedInFlight.values) {
      _cancelExtensionRequestUnawaited(inFlight.requestId);
    }
    _customSearchInFlight.clear();
    _homeFeedInFlight.clear();
    await _clearPersistentLookupCaches();
  }

  static String _nextExtensionRequestId(String kind, String extensionId) {
    _extensionRequestSequence++;
    return [
      kind,
      DateTime.now().microsecondsSinceEpoch,
      _extensionRequestSequence,
      extensionId.trim(),
    ].join(':');
  }

  static void _cancelExtensionRequestUnawaited(String requestId) {
    if (requestId.isEmpty) return;
    unawaited(
      cancelExtensionRequest(requestId).catchError((Object e) {
        _log.w('Failed to cancel extension request $requestId: $e');
      }),
    );
  }

  static Future<void> cancelExtensionRequest(String requestId) async {
    if (requestId.isEmpty) return;
    await _invoke('cancelExtensionRequestJSON', {'request_id': requestId});
  }

  static void _cancelCustomSearchInFlightForScope(
    String scopeKey, {
    String? exceptKey,
  }) {
    for (final entry in _customSearchInFlight.entries.toList()) {
      if (entry.key == exceptKey || entry.value.scopeKey != scopeKey) continue;
      _cancelExtensionRequestUnawaited(entry.value.requestId);
    }
  }

  static void cancelExtensionHomeFeedRequests() {
    for (final inFlight in _homeFeedInFlight.values) {
      _cancelExtensionRequestUnawaited(inFlight.requestId);
    }
    _homeFeedInFlight.clear();
  }

  static int _lookupCacheSize() {
    _pruneExpiredBridgeCache(_metadataCache);
    _pruneExpiredBridgeCache(_availabilityCache);
    return _metadataCache.length + _availabilityCache.length;
  }

  static Future<Map<String, dynamic>> _invokeDownloadMethod(
    String method,
    DownloadRequestPayload payload,
  ) async {
    final request = jsonEncode(payload.toJson());
    final result = await _invoke(method, request);
    return decodeRequiredMapResult(result, method);
  }

  static Future<Map<String, dynamic>> downloadByStrategy({
    required DownloadRequestPayload payload,
    bool? useExtensions,
    bool? useFallback,
  }) async {
    final routedPayload = payload.withStrategy(
      useExtensions: useExtensions,
      useFallback: useFallback,
    );
    _log.i(
      'downloadByStrategy: "${payload.trackName}" by ${payload.artistName} '
      '(service: ${payload.service}, ext: ${routedPayload.useExtensions}, fallback: ${routedPayload.useFallback})',
    );
    final response = await _invokeDownloadMethod(
      'downloadByStrategy',
      routedPayload,
    );
    if (response['success'] == true) {
      final service = response['service'] ?? payload.service;
      final filePath = response['file_path'] ?? '';
      final bitDepth = response['actual_bit_depth'] as num?;
      final sampleRate = response['actual_sample_rate'] as num?;
      final qualityStr =
          bitDepth != null && sampleRate != null
              ? ' ($bitDepth-bit/${(sampleRate / 1000).toStringAsFixed(1)}kHz)'
              : '';
      _log.i('Download success via $service$qualityStr: $filePath');
    } else {
      final error = response['error'] ?? 'Unknown error';
      final errorType = response['error_type'] ?? '';
      _log.e('Download failed: $error (type: $errorType)');
    }
    return response;
  }

  static Future<Map<String, dynamic>> getDownloadProgress() async {
    final result = await _invoke('getDownloadProgress');
    return decodeMapResult(result);
  }

  static Future<Map<String, dynamic>> getAllDownloadProgress() async {
    final result = await _invoke('getAllDownloadProgress');
    return decodeMapResult(result);
  }

  static Stream<Map<String, dynamic>> downloadProgressStream() {
    if (_useHttpBackend) {
      return _pollDownloadProgress();
    }
    return _downloadProgressEvents.receiveBroadcastStream().map(
      decodeMapResult,
    );
  }

  static Stream<Map<String, dynamic>> _pollDownloadProgress() async* {
    while (true) {
      try {
        await Future.delayed(const Duration(seconds: 1));
        final result = await _invoke('getAllDownloadProgress');
        if (result != null) {
          yield decodeMapResult(result);
        }
      } catch (_) {}
    }
  }

  static Future<void> exitApp() async {
    await _invoke('exitApp');
  }

  static Future<void> initItemProgress(String itemId) async {
    await _invoke('initItemProgress', {'item_id': itemId});
  }

  static Future<void> finishItemProgress(String itemId) async {
    await _invoke('finishItemProgress', {'item_id': itemId});
  }

  static Future<void> clearItemProgress(String itemId) async {
    await _invoke('clearItemProgress', {'item_id': itemId});
  }

  static Future<void> cancelDownload(String itemId) async {
    await _invoke('cancelDownload', {'item_id': itemId});
  }

  static Future<void> setDownloadDirectory(String path) async {
    await _invoke('setDownloadDirectory', {'path': path});
  }

  static Future<void> setNetworkCompatibilityOptions({
    required bool allowHttp,
    required bool insecureTls,
  }) async {
    await _invoke('setNetworkCompatibilityOptions', {
      'allow_http': allowHttp,
      'insecure_tls': insecureTls,
    });
  }

  static Future<Map<String, dynamic>> checkDuplicate(
    String outputDir,
    String isrc,
  ) async {
    final result = await _invoke('checkDuplicate', {
      'output_dir': outputDir,
      'isrc': isrc,
    });
    return decodeRequiredMapResult(result, 'checkDuplicate');
  }

  static Future<String> buildFilename(
    String template,
    Map<String, dynamic> metadata,
  ) async {
    final result = await _invoke('buildFilename', {
      'template': template,
      'metadata': jsonEncode(metadata),
    });
    return result as String;
  }

  static Future<String> sanitizeFilename(String filename) async {
    final result = await _invoke('sanitizeFilename', {'filename': filename});
    return result as String;
  }

  static Future<Map<String, dynamic>?> pickSafTree() async {
    final result = await _invoke('pickSafTree');
    return decodeNullableMapResult(result, 'pickSafTree');
  }

  static Future<bool> safExists(String uri) async {
    final result = await _invoke('safExists', {'uri': uri});
    return result as bool;
  }

  static Future<bool> safDelete(String uri) async {
    final result = await _invoke('safDelete', {'uri': uri});
    return result as bool;
  }

  static Future<Map<String, dynamic>> safStat(String uri) async {
    final result = await _invoke('safStat', {'uri': uri});
    return decodeRequiredMapResult(result, 'safStat');
  }

  static Future<Map<String, dynamic>> resolveSafFile({
    required String treeUri,
    required String fileName,
    String relativeDir = '',
  }) async {
    final result = await _invoke('resolveSafFile', {
      'tree_uri': treeUri,
      'relative_dir': relativeDir,
      'file_name': fileName,
    });
    return decodeRequiredMapResult(result, 'resolveSafFile');
  }

  static Future<String?> copyContentUriToTemp(String uri) async {
    final result = await _invoke('safCopyToTemp', {'uri': uri});
    return result as String?;
  }

  static Future<bool> replaceContentUriFromPath(
    String uri,
    String srcPath,
  ) async {
    final result = await _invoke('safReplaceFromPath', {
      'uri': uri,
      'src_path': srcPath,
    });
    return result as bool;
  }

  static Future<String?> createSafFileFromPath({
    required String treeUri,
    required String relativeDir,
    required String fileName,
    required String mimeType,
    required String srcPath,
  }) async {
    final result = await _invoke('safCreateFromPath', {
      'tree_uri': treeUri,
      'relative_dir': relativeDir,
      'file_name': fileName,
      'mime_type': mimeType,
      'src_path': srcPath,
    });
    return result as String?;
  }

  static Future<void> openContentUri(String uri, {String mimeType = ''}) async {
    await _invoke('openContentUri', {'uri': uri, 'mime_type': mimeType});
  }

  static Future<bool> shareContentUri(String uri, {String title = ''}) async {
    final result = await _invoke('shareContentUri', {
      'uri': uri,
      'title': title,
    });
    return result as bool? ?? false;
  }

  static Future<bool> shareMultipleContentUris(
    List<String> uris, {
    String title = '',
  }) async {
    final result = await _invoke('shareMultipleContentUris', {
      'uris': uris,
      'title': title,
    });
    return result as bool? ?? false;
  }

  static Future<Map<String, dynamic>> fetchLyrics(
    String spotifyId,
    String trackName,
    String artistName, {
    int durationMs = 0,
  }) async {
    final result = await _invoke('fetchLyrics', {
      'spotify_id': spotifyId,
      'track_name': trackName,
      'artist_name': artistName,
      'duration_ms': durationMs,
    });
    return decodeRequiredMapResult(result, 'fetchLyrics');
  }

  static Future<String> getLyricsLRC(
    String spotifyId,
    String trackName,
    String artistName, {
    String? filePath,
    int durationMs = 0,
  }) async {
    final result = await _invoke('getLyricsLRC', {
      'spotify_id': spotifyId,
      'track_name': trackName,
      'artist_name': artistName,
      'file_path': filePath ?? '',
      'duration_ms': durationMs,
    });
    return result as String;
  }

  static Future<String> getTranslatedLyricsLRC(
    String spotifyId,
    String trackName,
    String artistName, {
    int durationMs = 0,
    String language = 'es',
  }) async {
    final result = await _invoke('getTranslatedLyricsLRC', {
      'spotify_id': spotifyId,
      'track_name': trackName,
      'artist_name': artistName,
      'duration_ms': durationMs,
      'language': language,
    });
    return result as String;
  }

  static Future<void> setTranslationLanguage(String language) async {
    await _invoke('setTranslationLanguageJSON', {'language': language});
  }

  static Future<String> getTranslationLanguage() async {
    final result = await _invoke('getTranslationLanguageJSON', {});
    return result as String;
  }

  static Future<Map<String, dynamic>> getLyricsLRCWithSource(
    String spotifyId,
    String trackName,
    String artistName, {
    String? filePath,
    int durationMs = 0,
  }) async {
    final result = await _invoke('getLyricsLRCWithSource', {
      'spotify_id': spotifyId,
      'track_name': trackName,
      'artist_name': artistName,
      'file_path': filePath ?? '',
      'duration_ms': durationMs,
    });
    return decodeRequiredMapResult(result, 'getLyricsLRCWithSource');
  }

  static Future<Map<String, dynamic>> embedLyricsToFile(
    String filePath,
    String lyrics,
  ) async {
    final result = await _invoke('embedLyricsToFile', {
      'file_path': filePath,
      'lyrics': lyrics,
    });
    return decodeRequiredMapResult(result, 'embedLyricsToFile');
  }

  static Future<String> searchYouTubeVideo({
    required String trackName,
    required String artistName,
  }) async {
    final result = await _invoke('searchYouTubeVideo', {
      'track_name': trackName,
      'artist_name': artistName,
    });
    return result as String;
  }

  static Future<String> searchTidalVideo({
    required String trackName,
    required String artistName,
  }) async {
    final result = await _invoke('searchTidalVideo', {
      'track_name': trackName,
      'artist_name': artistName,
    });
    return result as String;
  }

  static Future<String> searchQobuzVideo({
    required String trackName,
    required String artistName,
  }) async {
    final result = await _invoke('searchQobuzVideo', {
      'track_name': trackName,
      'artist_name': artistName,
    });
    return result as String;
  }

  static Future<String> downloadYouTubeVideo({
    required String trackName,
    required String artistName,
    required String outputPath,
  }) async {
    final result = await _invoke('downloadYouTubeVideo', {
      'track_name': trackName,
      'artist_name': artistName,
      'output_path': outputPath,
    });
    return result as String;
  }

  static Future<void> cleanupConnections() async {
    await _invoke('cleanupConnections');
  }

  static Future<Map<String, dynamic>> downloadCoverToFile(
    String coverUrl,
    String outputPath, {
    bool maxQuality = true,
  }) async {
    final result = await _invoke('downloadCoverToFile', {
      'cover_url': coverUrl,
      'output_path': outputPath,
      'max_quality': maxQuality,
    });
    return decodeRequiredMapResult(result, 'downloadCoverToFile');
  }

  static Future<Map<String, dynamic>> extractCoverToFile(
    String audioPath,
    String outputPath,
  ) async {
    final result = await _invoke('extractCoverToFile', {
      'audio_path': audioPath,
      'output_path': outputPath,
    });
    return decodeRequiredMapResult(result, 'extractCoverToFile');
  }

  static Future<Map<String, dynamic>> fetchAndSaveLyrics({
    required String trackName,
    required String artistName,
    required String spotifyId,
    required int durationMs,
    required String outputPath,
    String audioFilePath = '',
  }) async {
    final result = await _invoke('fetchAndSaveLyrics', {
      'track_name': trackName,
      'artist_name': artistName,
      'spotify_id': spotifyId,
      'duration_ms': durationMs,
      'output_path': outputPath,
      'audio_file_path': audioFilePath,
    });
    return decodeRequiredMapResult(result, 'fetchAndSaveLyrics');
  }

  /// Providers not in the list are disabled.
  static Future<void> setLyricsProviders(List<String> providers) async {
    final providersJSON = jsonEncode(providers);
    await _invoke('setLyricsProvidersJSON', {'providers_json': providersJSON});
  }

  static Future<List<String>> getLyricsProviders() async {
    final result = await _invoke('getLyricsProvidersJSON');
    return decodeStringListResult(result, 'getLyricsProviders');
  }

  static Future<List<Map<String, dynamic>>>
  getAvailableLyricsProviders() async {
    final result = await _invoke('getAvailableLyricsProvidersJSON');
    return decodeMapListResult(result, 'getAvailableLyricsProviders');
  }

  /// Sets advanced lyrics fetch options used by provider-specific integrations.
  static Future<void> setLyricsFetchOptions(
    Map<String, dynamic> options,
  ) async {
    final optionsJSON = jsonEncode(options);
    await _invoke('setLyricsFetchOptionsJSON', {'options_json': optionsJSON});
  }

  static Future<Map<String, dynamic>> getLyricsFetchOptions() async {
    final result = await _invoke('getLyricsFetchOptionsJSON');
    return decodeRequiredMapResult(result, 'getLyricsFetchOptions');
  }

  static Future<Map<String, dynamic>> reEnrichFile(
    Map<String, dynamic> request,
  ) async {
    final requestJSON = jsonEncode(request);
    final result = await _invoke('reEnrichFile', {'request_json': requestJSON});
    return decodeRequiredMapResult(result, 'reEnrichFile');
  }

  static Future<Map<String, dynamic>> readFileMetadata(String filePath) async {
    final result = await _invoke('readFileMetadata', {'file_path': filePath});
    return decodeRequiredMapResult(result, 'readFileMetadata');
  }

  static Future<Map<String, dynamic>> editFileMetadata(
    String filePath,
    Map<String, String> metadata,
  ) async {
    final metadataJSON = jsonEncode(metadata);
    final result = await _invoke('editFileMetadata', {
      'file_path': filePath,
      'metadata_json': metadataJSON,
    });
    return decodeRequiredMapResult(result, 'editFileMetadata');
  }

  /// Rewrites ARTIST/ALBUMARTIST Vorbis comments as multiple split entries
  /// using the native Go FLAC writer, fixing FFmpeg's tag deduplication.
  static Future<Map<String, dynamic>> rewriteSplitArtistTags(
    String filePath,
    String artist,
    String albumArtist,
  ) async {
    final result = await _invoke('rewriteSplitArtistTags', {
      'file_path': filePath,
      'artist': artist,
      'album_artist': albumArtist,
    });
    return decodeRequiredMapResult(result, 'rewriteSplitArtistTags');
  }

  static Future<bool> writeTempToSaf(String tempPath, String safUri) async {
    final result = await _invoke('writeTempToSaf', {
      'temp_path': tempPath,
      'saf_uri': safUri,
    });
    final map = decodeRequiredMapResult(result, 'writeTempToSaf');
    return map['success'] == true;
  }

  static Future<void> startDownloadService({
    String trackName = '',
    String artistName = '',
    int queueCount = 0,
  }) async {
    await _invoke('startDownloadService', {
      'track_name': trackName,
      'artist_name': artistName,
      'queue_count': queueCount,
    });
  }

  static Future<void> stopDownloadService() async {
    await _invoke('stopDownloadService');
  }

  static Future<void> updateDownloadServiceProgress({
    required String trackName,
    required String artistName,
    required int progress,
    required int total,
    required int queueCount,
    String status = 'downloading',
  }) async {
    await _invoke('updateDownloadServiceProgress', {
      'track_name': trackName,
      'artist_name': artistName,
      'progress': progress,
      'total': total,
      'queue_count': queueCount,
      'status': status,
    });
  }

  static Future<bool> isDownloadServiceRunning() async {
    final result = await _invoke('isDownloadServiceRunning');
    return result as bool;
  }

  static Future<void> startNativeDownloadWorker({
    required List<Map<String, dynamic>> requests,
    Map<String, dynamic> settings = const {},
  }) async {
    final requestsJson = jsonEncode(requests);
    final settingsJson = jsonEncode(settings);
    final payloadDir = await _nativeWorkerPayloadDir();
    await _cleanupNativeWorkerPayloads(payloadDir);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final requestPath = '${payloadDir.path}/requests_$stamp.json';
    final settingsPath = '${payloadDir.path}/settings_$stamp.json';
    await File(requestPath).writeAsString(requestsJson, flush: true);
    await File(settingsPath).writeAsString(settingsJson, flush: true);
    try {
      await _invoke('startNativeDownloadWorker', {
        'requests_path': requestPath,
        'settings_path': settingsPath,
      });
    } catch (_) {
      unawaited(_deleteFileIfExists(requestPath));
      unawaited(_deleteFileIfExists(settingsPath));
      rethrow;
    }
  }

  static Future<void> _deleteFileIfExists(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  static Future<Directory> _nativeWorkerPayloadDir() async {
    final tempDir = await getTemporaryDirectory();
    final payloadDir = Directory('${tempDir.path}/native_worker_payloads');
    if (!await payloadDir.exists()) {
      await payloadDir.create(recursive: true);
    }
    return payloadDir;
  }

  static Future<void> _cleanupNativeWorkerPayloads(Directory payloadDir) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 1));
    try {
      await for (final entity in payloadDir.list(followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  static Future<void> pauseNativeDownloadWorker() async {
    await _invoke('pauseNativeDownloadWorker');
  }

  static Future<void> resumeNativeDownloadWorker() async {
    await _invoke('resumeNativeDownloadWorker');
  }

  static Future<void> cancelNativeDownloadWorker() async {
    await _invoke('cancelNativeDownloadWorker');
  }

  static Future<Map<String, dynamic>> getNativeDownloadWorkerSnapshot() async {
    final result = await _invoke('getNativeDownloadWorkerSnapshot');
    return decodeMapResult(result);
  }

  static Future<void> preWarmTrackCache(
    List<Map<String, String>> tracks,
  ) async {
    final tracksJson = jsonEncode(tracks);
    await _invoke('preWarmTrackCache', {'tracks': tracksJson});
  }

  static Future<int> getTrackCacheSize() async {
    await _ensurePersistentLookupCachesLoaded();
    final result = await _invoke('getTrackCacheSize');
    return (result as int) + _lookupCacheSize();
  }

  static Future<void> clearTrackCache() async {
    await _clearLookupCaches();
    await _invoke('clearTrackCache');
  }

  static Future<Map<String, dynamic>> getDeezerRelatedArtists(
    String artistId, {
    int limit = 12,
  }) async {
    final result = await _invoke('getDeezerRelatedArtists', {
      'artist_id': artistId,
      'limit': limit,
    });
    return decodeRequiredMapResult(result, 'getDeezerRelatedArtists');
  }

  static Future<Map<String, dynamic>> getProviderMetadata(
    String providerId,
    String resourceType,
    String resourceId,
  ) async {
    final cacheKey = _providerMetadataCacheKey(
      providerId,
      resourceType,
      resourceId,
    );
    await _ensurePersistentLookupCachesLoaded();
    final cached = _getCachedMap(_metadataCache, cacheKey);
    if (cached != null) return cached;

    final inFlight = _metadataInFlight[cacheKey];
    if (inFlight != null) return copyStringMap(await inFlight);

    final generation = _lookupCacheGeneration;
    final future = _invokeCachedMap(
      cacheKey,
      _metadataCache,
      () async {
        final result = await _invoke('getProviderMetadata', {
          'provider_id': providerId,
          'resource_type': resourceType,
          'resource_id': resourceId,
        });
        if (result == null) {
          throw Exception(
            'getProviderMetadata returned null for $providerId:$resourceType:$resourceId',
          );
        }
        return decodeRequiredMapResult(result, 'getProviderMetadata');
      },
      _metadataCacheTtl,
      generation,
      _metadataPersistentCacheKey,
    );
    _metadataInFlight[cacheKey] = future;
    try {
      return copyStringMap(await future);
    } finally {
      _metadataInFlight.remove(cacheKey);
    }
  }

  static Future<Map<String, dynamic>> searchDeezerByISRC(
    String isrc, {
    String? itemId,
  }) async {
    final result = await _invoke('searchDeezerByISRC', {
      'isrc': isrc,
      'item_id': itemId ?? '',
    });
    return decodeRequiredMapResult(result, 'searchDeezerByISRC');
  }

  static Future<Map<String, String>?> getDeezerExtendedMetadata(
    String trackId,
  ) async {
    try {
      final result = await _invoke('getDeezerExtendedMetadata', {
        'track_id': trackId,
      });
      if (result == null) return null;
      final data = decodeRequiredMapResult(result, 'getDeezerExtendedMetadata');
      return {
        'genre': data['genre'] as String? ?? '',
        'label': data['label'] as String? ?? '',
        'copyright': data['copyright'] as String? ?? '',
      };
    } catch (e) {
      _log.w('Failed to get Deezer extended metadata for $trackId: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> convertSpotifyToDeezer(
    String resourceType,
    String spotifyId,
  ) async {
    final cacheKey = _providerMetadataCacheKey(
      'spotify-to-deezer',
      resourceType,
      spotifyId,
    );
    await _ensurePersistentLookupCachesLoaded();
    final cached = _getCachedMap(_metadataCache, cacheKey);
    if (cached != null) return cached;

    final inFlight = _metadataInFlight[cacheKey];
    if (inFlight != null) return copyStringMap(await inFlight);

    final generation = _lookupCacheGeneration;
    final future = _invokeCachedMap(
      cacheKey,
      _metadataCache,
      () async {
        final result = await _invoke('convertSpotifyToDeezer', {
          'resource_type': resourceType,
          'spotify_id': spotifyId,
        });
        return decodeRequiredMapResult(result, 'convertSpotifyToDeezer');
      },
      _metadataCacheTtl,
      generation,
      _metadataPersistentCacheKey,
    );
    _metadataInFlight[cacheKey] = future;
    try {
      return copyStringMap(await future);
    } finally {
      _metadataInFlight.remove(cacheKey);
    }
  }

  static Future<List<Map<String, dynamic>>> getGoLogs() async {
    final result = await _invoke('getLogs');
    return decodeMapListResult(result, 'getGoLogs');
  }

  static Future<Map<String, dynamic>> getGoLogsSince(int index) async {
    final result = await _invoke('getLogsSince', {'index': index});
    return decodeRequiredMapResult(result, 'getGoLogsSince');
  }

  static Future<void> clearGoLogs() async {
    await _invoke('clearLogs');
  }

  static Future<int> getGoLogCount() async {
    final result = await _invoke('getLogCount');
    return result as int;
  }

  static Future<void> setGoLoggingEnabled(bool enabled) async {
    await _invoke('setLoggingEnabled', {'enabled': enabled});
  }

  static Future<void> initExtensionSystem(
    String extensionsDir,
    String dataDir,
  ) async {
    _log.d('initExtensionSystem: $extensionsDir, $dataDir');
    await _invoke('initExtensionSystem', {
      'extensions_dir': extensionsDir,
      'data_dir': dataDir,
    });
  }

  static Future<Map<String, dynamic>> loadExtensionsFromDir(
    String dirPath,
  ) async {
    _log.d('loadExtensionsFromDir: $dirPath');
    final result = await _invoke('loadExtensionsFromDir', {
      'dir_path': dirPath,
    });
    return decodeRequiredMapResult(result, 'loadExtensionsFromDir');
  }

  static Future<Map<String, dynamic>> loadExtensionFromPath(
    String filePath,
  ) async {
    _log.d('loadExtensionFromPath: $filePath');
    await _clearLookupCaches();
    final result = await _invoke('loadExtensionFromPath', {
      'file_path': filePath,
    });
    return decodeRequiredMapResult(result, 'loadExtensionFromPath');
  }

  static Future<void> unloadExtension(String extensionId) async {
    _log.d('unloadExtension: $extensionId');
    await _clearLookupCaches();
    await _invoke('unloadExtension', {'extension_id': extensionId});
  }

  static Future<void> removeExtension(String extensionId) async {
    _log.d('removeExtension: $extensionId');
    await _clearLookupCaches();
    await _invoke('removeExtension', {'extension_id': extensionId});
  }

  static Future<Map<String, dynamic>> upgradeExtension(String filePath) async {
    _log.d('upgradeExtension: $filePath');
    await _clearLookupCaches();
    final result = await _invoke('upgradeExtension', {'file_path': filePath});
    return decodeRequiredMapResult(result, 'upgradeExtension');
  }

  static Future<Map<String, dynamic>> checkExtensionUpgrade(
    String filePath,
  ) async {
    _log.d('checkExtensionUpgrade: $filePath');
    final result = await _invoke('checkExtensionUpgrade', {
      'file_path': filePath,
    });
    return decodeRequiredMapResult(result, 'checkExtensionUpgrade');
  }

  static Future<List<Map<String, dynamic>>> getInstalledExtensions() async {
    final result = await _invoke('getInstalledExtensions');
    return decodeMapListResult(result, 'getInstalledExtensions');
  }

  static Future<void> setExtensionEnabled(
    String extensionId,
    bool enabled,
  ) async {
    _log.d('setExtensionEnabled: $extensionId = $enabled');
    await _clearLookupCaches();
    await _invoke('setExtensionEnabled', {
      'extension_id': extensionId,
      'enabled': enabled,
    });
  }

  static Future<void> setProviderPriority(List<String> providerIds) async {
    _log.d('setProviderPriority: $providerIds');
    await _clearLookupCaches();
    await _invoke('setProviderPriorityJSON', {
      'priority': jsonEncode(providerIds),
    });
  }

  static Future<List<String>> getProviderPriority() async {
    final result = await _invoke('getProviderPriorityJSON');
    return decodeStringListResult(result, 'getProviderPriority');
  }

  static Future<void> setDownloadFallbackExtensionIds(
    List<String>? extensionIds,
  ) async {
    _log.d('setDownloadFallbackExtensionIds: $extensionIds');
    await _clearLookupCaches();
    await _invoke('setDownloadFallbackExtensionIdsJSON', {
      'extension_ids': extensionIds == null ? '' : jsonEncode(extensionIds),
    });
  }

  static Future<void> setMetadataProviderPriority(
    List<String> providerIds,
  ) async {
    _log.d('setMetadataProviderPriority: $providerIds');
    await _clearLookupCaches();
    await _invoke('setMetadataProviderPriorityJSON', {
      'priority': jsonEncode(providerIds),
    });
  }

  static Future<List<String>> getMetadataProviderPriority() async {
    final result = await _invoke('getMetadataProviderPriorityJSON');
    return decodeStringListResult(result, 'getMetadataProviderPriority');
  }

  static Future<Map<String, dynamic>> getExtensionSettings(
    String extensionId,
  ) async {
    final result = await _invoke('getExtensionSettingsJSON', {
      'extension_id': extensionId,
    });
    return decodeRequiredMapResult(result, 'getExtensionSettings');
  }

  static Future<Map<String, dynamic>> checkExtensionHealth(
    String extensionId,
  ) async {
    final result = await _invoke('checkExtensionHealth', {
      'extension_id': extensionId,
    });
    return decodeRequiredMapResult(result, 'checkExtensionHealth');
  }

  static Future<void> setExtensionSettings(
    String extensionId,
    Map<String, dynamic> settings,
  ) async {
    _log.d('setExtensionSettings: $extensionId');
    await _clearLookupCaches();
    await _invoke('setExtensionSettingsJSON', {
      'extension_id': extensionId,
      'settings': jsonEncode(settings),
    });
  }

  static Future<Map<String, dynamic>> invokeExtensionAction(
    String extensionId,
    String actionName,
  ) async {
    _log.d('invokeExtensionAction: $extensionId.$actionName');
    final result = await _invoke('invokeExtensionAction', {
      'extension_id': extensionId,
      'action': actionName,
    });
    if (result == null || (result as String).isEmpty) {
      return {'success': true};
    }
    return decodeRequiredMapResult(result, 'invokeExtensionAction');
  }

  static Future<List<Map<String, dynamic>>> searchTracksWithExtensions(
    String query, {
    int limit = 20,
  }) async {
    _log.d('searchTracksWithExtensions: "$query"');
    final result = await _invoke('searchTracksWithExtensions', {
      'query': query,
      'limit': limit,
    });
    return decodeMapListResult(result, 'searchTracksWithExtensions');
  }

  static Future<List<Map<String, dynamic>>> searchTracksWithMetadataProviders(
    String query, {
    int limit = 20,
    bool includeExtensions = true,
  }) async {
    _log.d(
      'searchTracksWithMetadataProviders: "$query", includeExtensions=$includeExtensions',
    );
    final result = await _invoke('searchTracksWithMetadataProviders', {
      'query': query,
      'limit': limit,
      'include_extensions': includeExtensions,
    });
    return decodeMapListResult(result, 'searchTracksWithMetadataProviders');
  }

  static Future<void> cleanupExtensions() async {
    _log.d('cleanupExtensions');
    await _invoke('cleanupExtensions');
  }

  static Future<Map<String, dynamic>?> getExtensionPendingAuth(
    String extensionId,
  ) async {
    final result = await _invoke('getExtensionPendingAuth', {
      'extension_id': extensionId,
    });
    return decodeNullableMapResult(result, 'getExtensionPendingAuth');
  }

  static Future<void> setExtensionAuthCode(
    String extensionId,
    String authCode,
  ) async {
    _log.d('setExtensionAuthCode: $extensionId');
    await _invoke('setExtensionAuthCode', {
      'extension_id': extensionId,
      'auth_code': authCode,
    });
  }

  static Future<void> setExtensionTokens(
    String extensionId, {
    required String accessToken,
    String? refreshToken,
    int? expiresIn,
  }) async {
    _log.d('setExtensionTokens: $extensionId');
    await _invoke('setExtensionTokens', {
      'extension_id': extensionId,
      'access_token': accessToken,
      'refresh_token': refreshToken ?? '',
      'expires_in': expiresIn ?? 0,
    });
  }

  static Future<void> clearExtensionPendingAuth(String extensionId) async {
    await _invoke('clearExtensionPendingAuth', {'extension_id': extensionId});
  }

  static Future<bool> isExtensionAuthenticated(String extensionId) async {
    final result = await _invoke('isExtensionAuthenticated', {
      'extension_id': extensionId,
    });
    return result as bool;
  }

  static Future<List<Map<String, dynamic>>> getAllPendingAuthRequests() async {
    final result = await _invoke('getAllPendingAuthRequests');
    return decodeMapListResult(result, 'getAllPendingAuthRequests');
  }

  static Future<Map<String, dynamic>?> getPendingFFmpegCommand(
    String commandId,
  ) async {
    final result = await _invoke('getPendingFFmpegCommand', {
      'command_id': commandId,
    });
    return decodeNullableMapResult(result, 'getPendingFFmpegCommand');
  }

  static Future<void> setFFmpegCommandResult(
    String commandId, {
    required bool success,
    String output = '',
    String error = '',
  }) async {
    await _invoke('setFFmpegCommandResult', {
      'command_id': commandId,
      'success': success,
      'output': output,
      'error': error,
    });
  }

  static Future<List<Map<String, dynamic>>>
  getAllPendingFFmpegCommands() async {
    final result = await _invoke('getAllPendingFFmpegCommands');
    return decodeMapListResult(result, 'setFFmpegCommandResult');
  }

  static Future<List<Map<String, dynamic>>> customSearchWithExtension(
    String extensionId,
    String query, {
    Map<String, dynamic>? options,
    bool cancelPrevious = false,
  }) async {
    final optionsJson = options != null ? jsonEncode(options) : '';
    final scopeKey = 'customSearch:${extensionId.trim()}';
    final cacheKey = [
      scopeKey,
      query,
      jsonEncode(canonicalizeJsonLike(options ?? const <String, dynamic>{})),
    ].join('\n');
    final inFlight = _customSearchInFlight[cacheKey];
    if (inFlight != null) return copyMapList(await inFlight.future);
    if (cancelPrevious) {
      _cancelCustomSearchInFlightForScope(scopeKey, exceptKey: cacheKey);
    }

    final requestId = _nextExtensionRequestId('customSearch', extensionId);
    final future =
        (() async {
          final result = await _invoke('customSearchWithExtension', {
            'extension_id': extensionId,
            'query': query,
            'options': optionsJson,
            'request_id': requestId,
          });
          return decodeMapListResult(result, 'customSearchWithExtension');
        })();

    final entry = BridgeInFlight<List<Map<String, dynamic>>>(
      requestId: requestId,
      scopeKey: scopeKey,
      future: future,
    );
    _customSearchInFlight[cacheKey] = entry;
    try {
      return copyMapList(await future);
    } finally {
      if (identical(_customSearchInFlight[cacheKey], entry)) {
        _customSearchInFlight.remove(cacheKey);
      }
    }
  }

  static Future<List<Map<String, dynamic>>> getSearchProviders() async {
    final result = await _invoke('getSearchProviders');
    return decodeMapListResult(result, 'getSearchProviders');
  }

  static Future<Map<String, dynamic>?> handleURLWithExtension(
    String url,
  ) async {
    try {
      final result = await _invoke('handleURLWithExtension', {'url': url});
      return decodeNullableMapResult(result, 'handleURLWithExtension');
    } catch (e) {
      return null;
    }
  }

  static Future<String?> findURLHandler(String url) async {
    final result = await _invoke('findURLHandler', {'url': url});
    if (result == null || result == '') return null;
    return result as String;
  }

  static Future<List<Map<String, dynamic>>> getURLHandlers() async {
    final result = await _invoke('getURLHandlers');
    return decodeMapListResult(result, 'getURLHandlers');
  }

  static Future<Map<String, dynamic>?> getExtensionHomeFeed(
    String extensionId, {
    bool cancelPrevious = false,
  }) async {
    final cacheKey = 'homeFeed:${extensionId.trim()}';
    final inFlight = _homeFeedInFlight[cacheKey];
    if (inFlight != null) {
      if (!cancelPrevious) {
        return copyNullableStringMap(await inFlight.future);
      }
      _cancelExtensionRequestUnawaited(inFlight.requestId);
      _homeFeedInFlight.remove(cacheKey);
    }

    final requestId = _nextExtensionRequestId('homeFeed', extensionId);
    final future =
        (() async {
          try {
            final result = await _invoke('getExtensionHomeFeed', {
              'extension_id': extensionId,
              'request_id': requestId,
            });
            return decodeNullableMapResult(result, 'getExtensionHomeFeed');
          } catch (e) {
            _log.e('getExtensionHomeFeed failed: $e');
            return null;
          }
        })();
    final entry = BridgeInFlight<Map<String, dynamic>?>(
      requestId: requestId,
      scopeKey: cacheKey,
      future: future,
    );
    _homeFeedInFlight[cacheKey] = entry;
    try {
      return copyNullableStringMap(await future);
    } finally {
      if (identical(_homeFeedInFlight[cacheKey], entry)) {
        _homeFeedInFlight.remove(cacheKey);
      }
    }
  }

  static Future<Map<String, dynamic>?> getExtensionBrowseCategories(
    String extensionId,
  ) async {
    try {
      final result = await _invoke('getExtensionBrowseCategories', {
        'extension_id': extensionId,
      });
      return decodeNullableMapResult(result, 'getExtensionBrowseCategories');
    } catch (e) {
      _log.e('getExtensionBrowseCategories failed: $e');
      return null;
    }
  }

  static Future<void> setLibraryCoverCacheDir(String cacheDir) async {
    _log.i('setLibraryCoverCacheDir: $cacheDir');
    await _invoke('setLibraryCoverCacheDir', {'cache_dir': cacheDir});
  }

  static Future<List<Map<String, dynamic>>> scanLibraryFolder(
    String folderPath,
  ) async {
    _log.i('scanLibraryFolder: $folderPath');
    final result = await _invoke('scanLibraryFolder', {
      'folder_path': folderPath,
    });
    return decodeMapListResultAsync(result, 'scanLibraryFolder');
  }

  static Future<Map<String, dynamic>> scanLibraryFolderIncremental(
    String folderPath,
    Map<String, int> existingFiles,
  ) async {
    _log.i(
      'scanLibraryFolderIncremental: $folderPath (${existingFiles.length} existing files)',
    );
    final result = await _invoke('scanLibraryFolderIncremental', {
      'folder_path': folderPath,
      'existing_files': jsonEncode(existingFiles),
    });
    return decodeRequiredMapResultAsync(result, 'scanLibraryFolderIncremental');
  }

  static Future<Map<String, dynamic>> scanLibraryFolderIncrementalFromSnapshot(
    String folderPath,
    String snapshotPath,
  ) async {
    final result = await _invoke('scanLibraryFolderIncrementalFromSnapshot', {
      'folder_path': folderPath,
      'snapshot_path': snapshotPath,
    });
    return decodeRequiredMapResultAsync(
      result,
      'scanLibraryFolderIncrementalFromSnapshot',
    );
  }

  static Future<List<Map<String, dynamic>>> scanSafTree(String treeUri) async {
    _log.i('scanSafTree: $treeUri');
    final result = await _invoke('scanSafTree', {'tree_uri': treeUri});
    return decodeMapListResultAsync(result, 'scanSafTree');
  }

  static Future<Map<String, dynamic>> scanSafTreeIncremental(
    String treeUri,
    Map<String, int> existingFiles,
  ) async {
    _log.i(
      'scanSafTreeIncremental: $treeUri (${existingFiles.length} existing files)',
    );
    final result = await _invoke('scanSafTreeIncremental', {
      'tree_uri': treeUri,
      'existing_files': jsonEncode(existingFiles),
    });
    return decodeRequiredMapResultAsync(result, 'scanSafTreeIncremental');
  }

  static Future<Map<String, dynamic>> scanSafTreeIncrementalFromSnapshot(
    String treeUri,
    String snapshotPath,
  ) async {
    final result = await _invoke('scanSafTreeIncrementalFromSnapshot', {
      'tree_uri': treeUri,
      'snapshot_path': snapshotPath,
    });
    return decodeRequiredMapResultAsync(
      result,
      'scanSafTreeIncrementalFromSnapshot',
    );
  }

  static Future<Map<String, int>> getSafFileModTimes(List<String> uris) async {
    final result = await _invoke('getSafFileModTimes', {
      'uris': jsonEncode(uris),
    });
    final map = decodeRequiredMapResult(result, 'getSafFileModTimes');
    return map.map((key, value) => MapEntry(key, (value as num).toInt()));
  }

  static Future<Map<String, dynamic>> getLibraryScanProgress() async {
    final result = await _invoke('getLibraryScanProgress');
    return decodeMapResult(result);
  }

  static Stream<Map<String, dynamic>> libraryScanProgressStream() {
    if (_useHttpBackend) {
      return _pollLibraryScanProgress();
    }
    return _libraryScanProgressEvents.receiveBroadcastStream().map(
      decodeMapResult,
    );
  }

  static Stream<Map<String, dynamic>> _pollLibraryScanProgress() async* {
    while (true) {
      try {
        await Future.delayed(const Duration(seconds: 1));
        final result = await _invoke('getLibraryScanProgress');
        if (result != null) {
          yield decodeMapResult(result);
        }
      } catch (_) {}
    }
  }

  static Future<void> cancelLibraryScan() async {
    await _invoke('cancelLibraryScan');
  }

  // MARK: - iOS Security-Scoped Bookmark

  /// Create a security-scoped bookmark from a filesystem path picked by
  /// FilePicker on iOS. Must be called while the picker session is still active.
  /// Returns base64-encoded bookmark data, or null on failure.
  static Future<String?> createIosBookmarkFromPath(String path) async {
    try {
      final result = await _invoke('createIosBookmarkFromPath', {'path': path});
      return result as String?;
    } catch (e) {
      _log.w('Failed to create iOS bookmark from path: $e');
      return null;
    }
  }

  /// Resolve a base64-encoded iOS security-scoped bookmark and start accessing
  /// the resource. Returns the resolved filesystem path.
  /// The resource stays accessed until [stopAccessingIosBookmark] is called.
  static Future<String?> startAccessingIosBookmark(String bookmark) async {
    try {
      final result = await _invoke('startAccessingIosBookmark', {
        'bookmark': bookmark,
      });
      return result as String?;
    } catch (e) {
      _log.w('Failed to start accessing iOS bookmark: $e');
      return null;
    }
  }

  /// Stop accessing the currently active iOS security-scoped resource.
  static Future<void> stopAccessingIosBookmark() async {
    try {
      await _invoke('stopAccessingIosBookmark');
    } catch (e) {
      _log.w('Failed to stop accessing iOS bookmark: $e');
    }
  }

  static Future<Map<String, dynamic>?> readAudioMetadata(
    String filePath,
  ) async {
    try {
      final result = await _invoke('readAudioMetadata', {
        'file_path': filePath,
      });
      return decodeNullableMapResult(result, 'readAudioMetadata');
    } catch (e) {
      _log.w('Failed to read audio metadata: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> runPostProcessing(
    String filePath, {
    Map<String, dynamic>? metadata,
  }) async {
    final result = await _invoke('runPostProcessing', {
      'file_path': filePath,
      'metadata': metadata != null ? jsonEncode(metadata) : '',
    });
    return decodeRequiredMapResult(result, 'runPostProcessing');
  }

  static Future<Map<String, dynamic>> runPostProcessingV2(
    String filePath, {
    Map<String, dynamic>? metadata,
  }) async {
    final input = <String, dynamic>{};
    if (filePath.startsWith('content://')) {
      input['uri'] = filePath;
    } else {
      input['path'] = filePath;
    }
    final result = await _invoke('runPostProcessingV2', {
      'input': jsonEncode(input),
      'metadata': metadata != null ? jsonEncode(metadata) : '',
    });
    return decodeRequiredMapResult(result, 'runPostProcessingV2');
  }

  static Future<List<Map<String, dynamic>>> getPostProcessingProviders() async {
    final result = await _invoke('getPostProcessingProviders');
    return decodeMapListResult(result, 'getPostProcessingProviders');
  }

  static Future<void> initExtensionStore(String cacheDir) async {
    _log.d('initExtensionStore: $cacheDir');
    await _invoke('initExtensionStore', {'cache_dir': cacheDir});
  }

  static Future<void> setStoreRegistryUrl(String registryUrl) async {
    _log.d('setStoreRegistryUrl: $registryUrl');
    await _invoke('setStoreRegistryURLJSON', {'registry_url': registryUrl});
  }

  static Future<String> getStoreRegistryUrl() async {
    _log.d('getStoreRegistryUrl');
    final result = await _invoke('getStoreRegistryURLJSON');
    return result as String? ?? '';
  }

  static Future<void> clearStoreRegistryUrl() async {
    _log.d('clearStoreRegistryUrl');
    await _invoke('clearStoreRegistryURLJSON');
  }

  static Future<List<Map<String, dynamic>>> getStoreExtensions({
    bool forceRefresh = false,
  }) async {
    _log.d('getStoreExtensions (forceRefresh: $forceRefresh)');
    final result = await _invoke('getStoreExtensionsJSON', {
      'force_refresh': forceRefresh,
    });
    return decodeMapListResult(result, 'getStoreExtensions');
  }

  static Future<List<Map<String, dynamic>>> searchStoreExtensions(
    String query, {
    String? category,
  }) async {
    _log.d('searchStoreExtensions: "$query" (category: $category)');
    final result = await _invoke('searchStoreExtensionsJSON', {
      'query': query,
      'category': category ?? '',
    });
    return decodeMapListResult(result, 'searchStoreExtensions');
  }

  static Future<List<String>> getStoreCategories() async {
    final result = await _invoke('getStoreCategoriesJSON');
    return decodeStringListResult(result, 'getStoreCategories');
  }

  static Future<String> downloadStoreExtension(
    String extensionId,
    String destDir,
  ) async {
    _log.i('downloadStoreExtension: $extensionId to $destDir');
    final result = await _invoke('downloadStoreExtensionJSON', {
      'extension_id': extensionId,
      'dest_dir': destDir,
    });
    return result as String;
  }

  static Future<void> clearStoreCache() async {
    _log.d('clearStoreCache');
    await _invoke('clearStoreCacheJSON');
  }

  static Future<Map<String, dynamic>> parseCueSheet(
    String cuePath, {
    String audioDir = '',
  }) async {
    _log.i('parseCueSheet: $cuePath (audioDir: $audioDir)');
    final result = await _invoke('parseCueSheet', {
      'cue_path': cuePath,
      'audio_dir': audioDir,
    });
    return decodeRequiredMapResult(result, 'parseCueSheet');
  }

  static Future<String?> convertAudioFile(String inputPath) async {
    try {
      final result = await _invoke('convertAudioFile', {
        'input_path': inputPath,
        'output_format': 'flac',
      });
      return result as String?;
    } catch (e) {
      _log.w('Audio conversion failed: $e');
      return null;
    }
  }

  // --- Playback Control ---
  static Future<String> playbackPlayTrack(String trackJson) async {
    final result = await _invoke('playbackPlayTrack', {
      'track_json': trackJson,
    });
    return result?.toString() ?? '{"success":false}';
  }

  static Future<String> playbackPause() async {
    final result = await _invoke('playbackPause');
    return result?.toString() ?? '{"success":false}';
  }

  static Future<String> playbackResume() async {
    final result = await _invoke('playbackResume');
    return result?.toString() ?? '{"success":false}';
  }

  static Future<String> playbackStop() async {
    final result = await _invoke('playbackStop');
    return result?.toString() ?? '{"success":false}';
  }

  static Future<String> playbackSeek(int positionMs) async {
    final result = await _invoke('playbackSeek', {'position_ms': positionMs});
    return result?.toString() ?? '{"success":false}';
  }

  static Future<String> playbackNext() async {
    final result = await _invoke('playbackNext');
    return result?.toString() ?? '{"success":false}';
  }

  static Future<String> playbackPrevious() async {
    final result = await _invoke('playbackPrevious');
    return result?.toString() ?? '{"success":false}';
  }

  static Future<String> playbackSetQueue(String tracksJson) async {
    final result = await _invoke('playbackSetQueue', {
      'tracks_json': tracksJson,
    });
    return result?.toString() ?? '{"success":false}';
  }

  static Future<String> playbackAddToQueue(String tracksJson) async {
    final result = await _invoke('playbackAddToQueue', {
      'tracks_json': tracksJson,
    });
    return result?.toString() ?? '{"success":false}';
  }

  static Future<String> playbackSetShuffle(bool enabled) async {
    final result = await _invoke('playbackSetShuffle', {'enabled': enabled});
    return result?.toString() ?? '{"success":false}';
  }

  static Future<String> playbackSetRepeat(String mode) async {
    final result = await _invoke('playbackSetRepeat', {'mode': mode});
    return result?.toString() ?? '{"success":false}';
  }

  static Future<String> playbackTrackCompleted() async {
    final result = await _invoke('playbackTrackCompleted');
    return result?.toString() ?? '{"success":false}';
  }

  static Future<String> playbackGetState() async {
    final result = await _invoke('playbackGetState');
    return result?.toString() ?? '{"success":false}';
  }

  static Future<String> playbackGetHistory(int limit) async {
    final result = await _invoke('playbackGetHistory', {'limit': limit});
    return result?.toString() ?? '{"history":[],"total":0}';
  }

  static Future<String> playbackGetQueue() async {
    final result = await _invoke('playbackGetQueue');
    return result?.toString() ?? '{"queue":[],"queue_index":-1}';
  }

  static Future<String> playbackRemoveFromQueue(int index) async {
    final result = await _invoke('playbackRemoveFromQueue', {'index': index});
    return result?.toString() ?? '{"success":false}';
  }

  static Future<String> playbackClearQueue() async {
    final result = await _invoke('playbackClearQueue');
    return result?.toString() ?? '{"success":false}';
  }

  static Future<void> playbackUpdatePosition(int positionMs) async {
    await _invoke('playbackUpdatePosition', {'position_ms': positionMs});
  }

  /// Check for updates on GitHub releases
  /// channel: 'stable' or 'preview'
  /// repo: GitHub repository in format 'owner/repo' (optional, defaults to AppInfo.githubRepo)
  static Future<Map<String, dynamic>> checkGitHubUpdate({
    String channel = 'stable',
    String? repo,
  }) async {
    final params = {
      'channel': channel,
      'current_version': AppInfo.version,
      'repo': repo ?? AppInfo.githubRepo,
    };
    // Enviar params directamente como mapa, el server los manejará
    final result = await _invoke('checkGitHubUpdate', params);
    return decodeRequiredMapResult(result, 'checkGitHubUpdate');
  }
}
