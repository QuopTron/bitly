import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

// ═══════════════════════════════════════════════════════════════════════
// Share Intent Service — handle incoming share intents (Android/iOS)
// ═══════════════════════════════════════════════════════════════════════

class ShareIntentService {
  static const _channel = MethodChannel('com.bitly/share_intent');
  static final ShareIntentService _instance = ShareIntentService._();
  static ShareIntentService get instance => _instance;

  final StreamController<String> _urlController = StreamController<String>.broadcast();
  Stream<String> get sharedUrls => _urlController.stream;

  ShareIntentService._();

  /// Initializes the share intent listener.
  Future<void> initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onSharedText':
          final text = call.arguments as String?;
          if (text != null && text.isNotEmpty) {
            _urlController.add(text);
          }
          break;
        case 'onSharedUrl':
          final url = call.arguments as String?;
          if (url != null && url.isNotEmpty) {
            _urlController.add(url);
          }
          break;
      }
    });

    // Check for initial share intent (app opened via share)
    try {
      final initialText = await _channel.invokeMethod<String>('getInitialSharedText');
      if (initialText != null && initialText.isNotEmpty) {
        _urlController.add(initialText);
      }
    } catch (_) {
      // Method not available on this platform
    }
  }

  /// Extracts music URLs from shared text.
  List<String> extractMusicUrls(String text) {
    final urls = <String>[];
    final urlPattern = RegExp(
      r'https?://[^\s<>"{}|\\^`\[\]]+',
      caseSensitive: false,
    );
    for (final match in urlPattern.allMatches(text)) {
      final url = match.group(0)!;
      if (_isMusicUrl(url)) {
        urls.add(url);
      }
    }
    return urls;
  }

  bool _isMusicUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('spotify.com') ||
        lower.contains('open.spotify.com') ||
        lower.contains('deezer.com') ||
        lower.contains('music.apple.com') ||
        lower.contains('tidal.com') ||
        lower.contains('soundcloud.com') ||
        lower.contains('youtube.com') ||
        lower.contains('music.youtube.com') ||
        lower.contains('qobuz.com') ||
        lower.contains('amazon.com/music');
  }

  void dispose() {
    _urlController.close();
  }
}
