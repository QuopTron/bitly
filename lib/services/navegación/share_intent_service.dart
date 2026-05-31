/// Servicio singleton que intercepta intents de compartir (share intents)
/// desde otras aplicaciones. Captura URIs de Spotify y URLs HTTP
/// genéricas, las procesa y las expone via un stream y un método
/// one-shot [consumePendingUrl].
library;

import 'dart:async';
import 'dart:io';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:bitly/utils/logger.dart';
import 'package:bitly/services/núcleo/base_service.dart';

class ShareIntentService extends BaseService {
  static final ShareIntentService _instance = ShareIntentService._internal();
  factory ShareIntentService() => _instance;
  ShareIntentService._internal();

  static final RegExp _spotifyUriPattern = RegExp(
    r'spotify:(track|album|playlist|artist):[a-zA-Z0-9]+',
  );
  static final RegExp _genericHttpUrlPattern = RegExp(
    "https?://[^\\s<>\"']+",
    caseSensitive: false,
  );

  final _sharedUrlController = StreamController<String>.broadcast();
  StreamSubscription<List<SharedMediaFile>>? _mediaSubscription;
  String? _pendingUrl;
  bool _initialized = false;
  late final _log = AppLogger('ShareIntent');

  Stream<String> get sharedUrlStream => _sharedUrlController.stream;

  String? consumePendingUrl() {
    final url = _pendingUrl;
    _pendingUrl = null;
    return url;
  }

  @override
  Future<void> onInitialize() async {
    if (_initialized) return;
    
    if (!Platform.isAndroid && !Platform.isIOS) {
      _log.i('Share intent is not supported on this platform');
      return;
    }

    _mediaSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleSharedMedia,
      onError: (Object err) => _log.e('Error: $err'),
    );

    final initialMedia = await ReceiveSharingIntent.instance.getInitialMedia();
    if (initialMedia.isNotEmpty) {
      _handleSharedMedia(initialMedia, isInitial: true);
      ReceiveSharingIntent.instance.reset();
    }
    
    _initialized = true;
  }

  void _handleSharedMedia(
    List<SharedMediaFile> files, {
    bool isInitial = false,
  }) {
    try {
      for (final file in files) {
        final textsToCheck = [file.path, if (file.message != null) file.message!];

        for (final textToCheck in textsToCheck) {
          final url = _extractMusicUrl(textToCheck);
          if (url != null) {
            _log.i('Received music URL: $url (initial: $isInitial)');
            if (isInitial) {
              _pendingUrl = url;
            }
            _sharedUrlController.add(url);
            return;
          }
        }
      }
    } catch (e) {
      _log.e('Error handling shared media: $e', e);
    }
  }

  String? _extractMusicUrl(String text) {
    try {
      if (text.isEmpty) return null;

      final uriMatch = _spotifyUriPattern.firstMatch(text);
      if (uriMatch != null) {
        return uriMatch.group(0);
      }

      // Keep share parsing generic and let manifest-based URL handlers decide
      // which installed extension can handle the incoming link.
      for (final match in _genericHttpUrlPattern.allMatches(text)) {
        final rawUrl = match.group(0);
        if (rawUrl == null || rawUrl.isEmpty) {
          continue;
        }

        final sanitizedUrl = rawUrl.replaceFirst(RegExp(r'[.,;:!?)]+$'), '');
        if (sanitizedUrl.isNotEmpty) {
          return sanitizedUrl;
        }
      }

      return null;
    } catch (e) {
      _log.e('Error extracting music URL: $e', e);
      return null;
    }
  }

  @override
  Future<void> onDispose() async {
    _mediaSubscription?.cancel();
    await _sharedUrlController.close();
    await super.onDispose();
  }

  @override
  Future<ServiceHealth> onCheckHealth() async {
    if (!isInitialized) {
      return ServiceHealth.degraded('Share intent service not initialized');
    }
    if (!Platform.isAndroid && !Platform.isIOS) {
      return ServiceHealth.degraded('Share intent not supported on this platform');
    }
    return ServiceHealth.healthy('Share intent service healthy');
  }
}