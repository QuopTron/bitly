import 'dart:async';
import 'dart:io';

/// Local loopback HTTP server used on desktop (Windows/Linux) to receive the
/// Cloudflare signed-session grant.
///
/// `webview_flutter` has no Windows/Linux implementation, so the in-app WebView
/// dialog can't be used there. Instead the challenge opens in the system
/// browser with `cb=http://127.0.0.1:<port>/session-grant` (the backend points
/// the callback there via `setSignedSessionCallbackUrl`). After the captcha,
/// the browser redirects to this server with `?grant=...`; the grant is
/// captured and the pending verification completes. The user sees a small
/// "you can close this tab" page.
class DesktopCallbackServer {
  DesktopCallbackServer._();

  static final DesktopCallbackServer instance = DesktopCallbackServer._();

  HttpServer? _server;
  Completer<String?>? _pending;
  Timer? _timeout;

  int? get port => _server?.port;

  bool get isReady => _server != null;

  /// Binds the loopback server on a random free port (idempotent).
  Future<bool> ensureStarted() async {
    if (_server != null) return true;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _server!.listen(_handle);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _handle(HttpRequest request) {
    final grant = request.uri.queryParameters['grant']?.trim();
    if (grant != null && grant.isNotEmpty) {
      // Respond before completing so the browser tab closes cleanly.
      request.response
        ..headers.contentType = ContentType.html
        ..write(_successPage);
      unawaited(request.response.close());
      _complete(grant);
      return;
    }
    request.response
      ..statusCode = HttpStatus.badRequest
      ..write('missing grant');
    unawaited(request.response.close());
  }

  static const _successPage = '''
<!DOCTYPE html><html><head><meta charset="utf-8">
<title>Verificación completada</title></head>
<body style="font-family:sans-serif;background:#000;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh">
<div style="text-align:center">
<h2>✔ Verificación completada</h2>
<p>Ya puedes cerrar esta pestaña y volver a la app.</p>
</div></body></html>''';

  /// Waits for the next grant (or null on timeout/cancel).
  Future<String?> waitForGrant(Duration timeout) {
    _complete(null); // cancel any stale waiter
    final completer = Completer<String?>();
    _pending = completer;
    _timeout = Timer(timeout, () => _complete(null));
    return completer.future;
  }

  /// Cancels any pending wait (e.g. the user chose to skip verification).
  void cancel() {
    _complete(null);
  }

  void _complete(String? grant) {
    final c = _pending;
    _pending = null;
    _timeout?.cancel();
    _timeout = null;
    if (c != null && !c.isCompleted) c.complete(grant);
  }
}
