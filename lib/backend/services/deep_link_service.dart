import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// Captures deep links (bitly://open?... or https://bitly.app/open?...)
/// and exposes them as a stream so the UI can show the "shared with you" overlay.
class DeepLinkService {
  static const _channel = MethodChannel('com.bitly/deep_link');
  static final DeepLinkService _instance = DeepLinkService._();
  static DeepLinkService get instance => _instance;

  final _controller = StreamController<DeepLinkData>.broadcast();
  Stream<DeepLinkData> get onDeepLink => _controller.stream;

  DeepLinkData? _pendingLink;
  DeepLinkData? get pendingLink => _pendingLink;

  DeepLinkService._();

  Future<void> initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final url = call.arguments as String?;
        if (url != null && url.isNotEmpty) {
          final data = _parse(url);
          if (data != null) {
            _pendingLink = data;
            _controller.add(data);
          }
        }
      }
    });

    // Check for initial deep link (app opened via link)
    try {
      final initial = await _channel.invokeMethod<String>('getInitialDeepLink');
      if (initial != null && initial.isNotEmpty) {
        final data = _parse(initial);
        if (data != null) {
          _pendingLink = data;
        }
      }
    } catch (_) {}
  }

  /// Consumes the pending deep link so the overlay doesn't re-show.
  DeepLinkData? consumePending() {
    final link = _pendingLink;
    _pendingLink = null;
    return link;
  }

  DeepLinkData? _parse(String url) {
    try {
      final uri = Uri.parse(url);
      final type = uri.queryParameters['type'] ?? 'track';
      final id = uri.queryParameters['id'] ?? '';
      final query = uri.queryParameters['q'] ?? '';
      if (id.isEmpty && query.isEmpty) return null;
      return DeepLinkData(type: type, id: id, query: query);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _controller.close();
  }
}

class DeepLinkData {
  final String type;
  final String id;
  final String query;

  const DeepLinkData({
    required this.type,
    required this.id,
    required this.query,
  });
}
