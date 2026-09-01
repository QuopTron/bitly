import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../rpc/backend_service.dart';
import '../../injection.dart';
import 'desktop_callback_server.dart';

final _log = Logger();

/// Extracts the grant code from a verification callback URL.
///
/// The backend callback URL is `spotiflac://session-grant?grant=...`
/// (legacy: `bitly://session-grant?...`). Matching by host (not scheme)
/// makes any custom-scheme callback work. Returns null when the URL is
/// not a session-grant callback or has no grant param.
String? verificationGrantFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host != 'session-grant') return null;
  final raw = uri.queryParameters['grant'];
  if (raw == null || raw.isEmpty) return null;
  return raw.trim();
}

/// Drives the Cloudflare signed-session verification (Turnstile challenge).
///
/// The challenge is shown in an **in-app dialog with an embedded WebView**
/// (keeps the UX inside the app). A Chrome-like User-Agent is used so
/// Cloudflare Turnstile renders correctly, and NO aggressive JS injection is
/// applied (the challenge page redirects to `spotiflac://session-grant` on
/// success, which the navigation delegate intercepts).
///
/// If the WebView fails, a button lets the user open the challenge in the
/// system browser instead; the grant then comes back through the
/// `spotiflac://session-grant` deep link (native side forwards it over the
/// `com.bitly/session_grant` MethodChannel).
class VerificationService with WidgetsBindingObserver {
  static final VerificationService _instance = VerificationService._();
  factory VerificationService() => _instance;
  VerificationService._();

  static const _channel = MethodChannel('com.bitly/session_grant');
  static const _grantTimeout = Duration(seconds: 90);
  static const _resumeGrace = Duration(seconds: 2);

  /// Real Chrome mobile UA so Turnstile does not flag the embedded WebView.
  static const _chromeUA =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  GlobalKey<NavigatorState>? _navigatorKey;

  // Only one verification is pending at a time (setup, search and download
  // flows all process providers sequentially).
  Completer<String?>? _pending;
  Timer? _timeout;
  bool _dialogOpen = false;
  // When the user skips verification the current provisioning run is disabled
  // (remaining sources return nulls so the app unlocks). Direct callers like
  // the setup slide still show their modal: the flag only applies while a
  // provisionSignedSessions run is active.
  bool _disabled = false;
  bool _runActive = false;
  // Set while the desktop browser flow is running (grant arrives via the local
  // HTTP server, not the deep link). Suppresses the resume auto-cancel so the
  // user can return to the app before completing the captcha.
  bool _browserFlow = false;

  void init(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSessionGrant') {
        _log.i('[VerificationService] Session grant received from deep link');
        _completePending((call.arguments as String? ?? '').trim());
      }
      return null;
    });
    WidgetsBinding.instance.addObserver(this);
  }

  bool get isReady => _navigatorKey != null;

  /// Signed-session providers that may host a (Cloudflare or auth) challenge
  /// WebView. Provisioning them at startup avoids VERIFY_REQUIRED failures
  /// during streaming/search/downloads.
  static const signedSessionSources = <String>[
    'qobuz-web', 'amazon', 'deezer', 'pandora', 'tidal-web',
  ];

  /// Provisions signed sessions for every Cloudflare/auth source at app start.
  ///
  /// Always probes EVERY signed-session source on launch — there is NO "still
  /// healthy, skip" shortcut. That guarantees the token of any extension that
  /// is missing, expired, or otherwise needs a fresh challenge reliably opens
  /// its Cloudflare modal BEFORE the app unlocks, so the user can update its
  /// token before doing anything else. Sources whose session is genuinely
  /// healthy get an empty URL from the backend and are skipped as a no-op
  /// (no modal), so a healthy setup doesn't force a captcha unnecessarily.
  /// Skips pending verification and disables further modal/browser prompts for
  /// this run, so the app never stays blocked on captchas.
  void skipAll() {
    _disabled = true;
    DesktopCallbackServer.instance.cancel();
    _completePending('');
  }

  Future<void> provisionSignedSessions() async {
    if (!isReady) return;
    final backend = sl<BackendService>();
    _runActive = true;
    _disabled = false;
    try {
      for (final source in signedSessionSources) {
        try {
          var url = await backend.getPendingVerificationUrl(source);
          if (url.isEmpty) {
            url = await backend.triggerExtensionVerification(source);
          }
          if (url.isEmpty) continue; // session healthy → nothing to verify
          // Give the Cloudflare challenge a generous window to complete,
          // mirroring SpotiFLAC's long grant wait (it allows up to 5 minutes).
          // A too-short cap (the previous 45s) silently skips sources whose
          // Turnstile renders slowly (emulators, slow WebViews) leaving their
          // session unverified — which resurfaces later as VERIFY_REQUIRED
          // spam during streams/downloads. Only a truly stuck challenge is
          // skipped, and re-probed on the next launch / on demand.
          final grant = await showVerification(
            extId: source,
            displayName: sourceDisplayName(source),
            authUrl: url,
            timeout: const Duration(seconds: 90),
          ).timeout(
            const Duration(seconds: 100),
            onTimeout: () {
              _log.w('[VerificationService] $source timed out during provision');
              _completePending('');
              return null;
            },
          );
          if (grant == null || grant.isEmpty) continue;
          await backend.completeSignedSessionGrant(source, grant);
        } catch (e) {
          _log.w('[VerificationService] Refreshing $source failed: $e');
        }
      }
    } finally {
      _runActive = false;
    }
  }

  String sourceDisplayName(String s) {
    switch (s) {
      case 'qobuz-web': return 'Qobuz';
      case 'amazon': return 'Amazon Music';
      case 'deezer': return 'Deezer';
      case 'pandora': return 'Pandora';
      case 'tidal-web': return 'TIDAL';
      default: return s;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user returned from the system browser (browser fallback). If the
    // grant deep link has not arrived yet, give it a short grace period;
    // otherwise fail fast instead of spinning for the full timeout.
    // Skip when the WebView dialog is open: that means the user just
    // backgrounded/returned without using the browser, so verification
    // should keep running in the dialog.
    if (state != AppLifecycleState.resumed) return;
    final pending = _pending;
    if (pending == null || _dialogOpen || _browserFlow) return;
    Timer(_resumeGrace, () {
      if (identical(pending, _pending)) _completePending('');
    });
  }

  /// Shows the Cloudflare challenge in an in-app WebView dialog and returns
  /// the grant code, or null if cancelled/timed out.
  Future<String?> showVerification({
    required String extId,
    required String displayName,
    required String authUrl,
    Duration? timeout,
  }) async {
    // Only honor a skip while a provisionSignedSessions run is active; direct
    // callers (setup slide) always get their modal.
    if (_disabled && _runActive) return null;
    _completePending(''); // cancel any stale pending completer
    final completer = Completer<String?>();
    _pending = completer;
    NavigatorState? dialogNav;

    // Desktop (Windows/Linux): webview_flutter is unsupported, so open the
    // challenge in the system browser and receive the grant on the local
    // loopback server (the backend pointed the challenge callback there). If
    // the callback server could not bind, skip the source rather than showing
    // a broken WebView dialog.
    final isDesktop = Platform.isWindows || Platform.isLinux;
    final desktopCallback = DesktopCallbackServer.instance;
    if (isDesktop) {
      if (!desktopCallback.isReady) {
        _log.w('[VerificationService] Desktop callback server unavailable, '
            'skipping $extId verification');
        _completePending('');
        return null;
      }
      _browserFlow = true;
      try {
        unawaited(_launchBrowser(displayName, authUrl));
        final grant = await desktopCallback.waitForGrant(
            timeout ?? _grantTimeout);
        _completePending(grant);
        return grant;
      } finally {
        _browserFlow = false;
      }
    }

    _timeout = Timer(timeout ?? _grantTimeout, () {
      _log.w('[VerificationService] Verification timed out after '
          '${(timeout ?? _grantTimeout).inMinutes} min');
      _completePending('');
      // Pop only the dialog route itself AND only while the dialog is actually
      // open. A blind Navigator.pop() at timeout can pop the go_router root's
      // last page and crash with 'popped the last page off of the stack'.
      final nav = dialogNav;
      if (nav != null && nav.mounted && nav.canPop() && _dialogOpen) {
        nav.pop();
      }
    });

    final ctx = _navigatorKey?.currentContext;
    if (ctx == null) {
      // No UI context available — fall back to the system browser.
      unawaited(_launchBrowser(displayName, authUrl));
      return completer.future;
    }

    _dialogOpen = true;
    try {
      await showDialog<void>(
        context: ctx,
        barrierDismissible: false,
        builder: (dialogCtx) {
          dialogNav = Navigator.of(dialogCtx);

          void finish(String? grant) {
            _completePending(grant);
            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
          }

          return VerificationDialog(
            displayName: displayName,
            authUrl: authUrl,
            onGrant: finish,
            onCancel: () => finish(null),
            onBrowser: () {
              // Keep the completer pending; the grant arrives via deep link.
              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              unawaited(_launchBrowser(displayName, authUrl));
            },
          );
        },
      );
    } finally {
      _dialogOpen = false;
    }

    return completer.future;
  }

  /// Opens the challenge in the system browser. The grant comes back through
  /// the `spotiflac://session-grant` deep link (native channel).
  Future<void> _launchBrowser(String displayName, String authUrl) async {
    _showWaitingHint(displayName);
    try {
      final ok = await launchUrl(
        Uri.parse(authUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) _launchFailed();
    } catch (e) {
      _log.e('[VerificationService] Error launching browser: $e');
      _launchFailed();
    }
  }

  // Browser could not be opened: end the pending verification immediately and
  // release the desktop callback server so the wait doesn't drag to timeout.
  void _launchFailed() {
    DesktopCallbackServer.instance.cancel();
    _completePending('');
  }

  void _showWaitingHint(String displayName) {
    final ctx = _navigatorKey?.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(
            'Se abrió el navegador — completa el captcha para $displayName'),
        duration: const Duration(seconds: 5),
      ));
  }

  /// Shows a short, action-less notice in the current app context. Used to
  /// surface playback failures that are otherwise silent (e.g. "Sesión de
  /// Deezer no verificada") when a tap can't resolve a stream.
  void showNotice(String message) {
    final ctx = _navigatorKey?.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
      ));
  }

  void _completePending(String? grant) {
    final c = _pending;
    _pending = null;
    _timeout?.cancel();
    _timeout = null;
    if (c != null && !c.isCompleted) {
      final g = grant?.trim() ?? '';
      c.complete(g.isEmpty ? null : _cleanGrant(g));
    }
  }

  String _cleanGrant(String raw) {
    final g = raw.trim();
    if (g.startsWith('grant=')) return g.substring(6);
    return g;
  }
}

/// In-app popup that hosts the Cloudflare challenge in an embedded WebView.
class VerificationDialog extends StatefulWidget {
  final String displayName;
  final String authUrl;
  final void Function(String grant) onGrant;
  final VoidCallback onCancel;
  final VoidCallback onBrowser;

  const VerificationDialog({
    super.key,
    required this.displayName,
    required this.authUrl,
    required this.onGrant,
    required this.onCancel,
    required this.onBrowser,
  });

  @override
  State<VerificationDialog> createState() => _VerificationDialogState();
}

class _VerificationDialogState extends State<VerificationDialog> {
  late final WebViewController _controller;
  bool _failed = false;
  bool _pageLoaded = false;
  Timer? _loadTimer;
  // The grant callback can fire from multiple navigation delegates for the
  // same URL (onUrlChange, onNavigationRequest, onPageStarted, onPageFinished).
  // Fire it exactly once so the dialog is popped exactly once.
  bool _grantFired = false;

  @override
  void initState() {
    super.initState();

    // If the challenge page doesn't load within 15 seconds, surface the
    // failure view so the user can retry or open in the external browser.
    // Without this timeout the dialog hangs indefinitely on emulators or
    // slow networks where Turnstile never renders.
    _loadTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && !_pageLoaded && !_failed && !_grantFired) {
        _log.w('[VerificationService] Page load timeout — showing failure view');
        setState(() => _failed = true);
      }
    });

    // Cloudflare Turnstile delivers the grant to the in-app WebView through
    // Path 1 of the challenge page: a JS bridge named `window.SpotiflacGrant`.
    // This is REQUIRED — Chromium silently drops the script-initiated
    // `spotiflac://session-grant?grant=...` custom-scheme navigation (Path 2)
    // because it has no user gesture, so without this channel the grant never
    // reaches the app and the signed session is never provisioned. The page
    // posts either the bare token or the full deep-link URL; both are parsed
    // here.
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'SpotiflacGrant',
        onMessageReceived: (message) {
          final grant = verificationGrantFromUrl(message.message);
          if (grant != null) _fireGrant(grant);
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onUrlChange: (change) => _check(change.url),
        onNavigationRequest: (request) {
          final grant = verificationGrantFromUrl(request.url);
          if (grant != null) {
            _fireGrant(grant);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onPageStarted: (url) => _check(url),
        onPageFinished: (url) {
          _check(url);
          if (mounted) {
            setState(() {
              _failed = false;
              _pageLoaded = true;
            });
          }
          _applyBranding(url);
        },
        onWebResourceError: (error) {
          // Sub-resource failures (scripts, CSS, fonts, images) are normal —
          // a blocked analytics/tracker script must NOT blank the dialog.
          // Only surface the failure view for real errors on the main frame.
          // Note: isForMainFrame can be null on some platforms, so treat null
          // the same as true (surface the error).
          if (error.isForMainFrame != false) {
            _log.e('[VerificationService] WebView error: '
                '${error.description} code=${error.errorCode} url=${error.url}');

            // The spotiflac:// redirect reports ERR_UNKNOWN_URL_SCHEME (varies
            // by device); the navigation delegate already captures the grant
            // before it fires, so treat it as expected.
            final isSchemeErr = error.errorCode == -10 ||
                error.description.toUpperCase().contains('UNKNOWN_URL_SCHEME') ||
                (error.url ?? '').startsWith('spotiflac://');
            if (!isSchemeErr && mounted) {
              setState(() => _failed = true);
            }
          }
        },
      ));

    // Chrome-like UA so Cloudflare Turnstile renders in the embedded WebView.
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      unawaited(platform.setUserAgent(VerificationService._chromeUA));
    }

    _controller.loadRequest(Uri.parse(widget.authUrl));
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    super.dispose();
  }

  void _check(String? url) {
    if (url == null) return;
    final grant = verificationGrantFromUrl(url);
    if (grant != null) _fireGrant(grant);
  }

  void _fireGrant(String grant) {
    if (_grantFired) return;
    _grantFired = true;
    _loadTimer?.cancel();
    widget.onGrant(grant);
  }

  /// Cosmetic re-brand of the captcha page (served by zarz.moe, which we don't
  /// control). Replaces the "SpotiFLAC-Mobile" chrome with the app's name while
  /// leaving the Turnstile widget and the SpotiflacGrant bridge untouched, so
  /// Cloudflare verification keeps working. Colors already match (both are
  /// Spotify-green). Safe no-op if the page changes or the selectors vanish.
  void _applyBranding(String url) {
    if (url.isEmpty || !url.contains('zarz.moe')) return;
    const js = '''
      (function(){
        function rebrand(){
          try {
            document.title = 'Verification - Bitly';
            var nav = document.querySelector('.nav-brand');
            if (nav) {
              var spans = nav.querySelectorAll('span');
              for (var i = 0; i < spans.length; i++) {
                if (spans[i] && !spans[i].className) { spans[i].textContent = 'bitly'; }
              }
            }
            // Re-map the challenge palette to Bitly's neon green + near-black.
            var root = document.documentElement;
            if (root) {
              root.style.setProperty('--green', '#5AF13D');
              root.style.setProperty('--green-dim', '#3FEF38');
              root.style.setProperty('--bg', '#000000');
              root.style.setProperty('--surface', '#1A1A1A');
              root.style.setProperty('--card', '#1A1A1A');
              root.style.setProperty('--card-hover', '#222222');
              root.style.setProperty('--text', '#ffffff');
            }
          } catch(e) {}
        }
        if (document.readyState === 'loading') {
          document.addEventListener('DOMContentLoaded', rebrand);
        } else {
          rebrand();
        }
      })();
    ''';
    unawaited(_controller.runJavaScript(js));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? Colors.white : Colors.black;
    final primary = Theme.of(context).colorScheme.primary;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined,
                      color: onBg.withValues(alpha: 0.6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Verificar ${widget.displayName}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: onBg,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: onBg.withValues(alpha: 0.5)),
                    onPressed: widget.onCancel,
                  ),
                ],
              ),
            ),
            // WebView
            SizedBox(
              height: 320,
              child: _failed
                  ? _failureView(isDark, primary)
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        WebViewWidget(controller: _controller),
                        if (!_pageLoaded)
                          CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primary,
                          ),
                      ],
                    ),
            ),
            // Footer actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Completa el captcha. Si no carga aquí, ábrelo en el navegador:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: onBg.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: widget.onBrowser,
                      icon: const Icon(Icons.open_in_browser, size: 18),
                      label: const Text('Abrir en el navegador'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primary,
                        side: BorderSide(color: primary.withValues(alpha: 0.6)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _failureView(bool isDark, Color primary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              'No se pudo cargar la verificación',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Toca "Abrir en el navegador" para completar el captcha.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _failed = false);
                _controller.reload();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
