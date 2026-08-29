import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../config/secrets.dart';
import '../services/premium_service.dart';
import '../../injection.dart';
import '../services/provider_credential_service.dart';
import '../services/desktop_callback_server.dart';
import '../cache/settings_cache.dart';
import 'backend_service.dart';
import 'mixins/settings_mixin.dart';
import 'mixins/feed_search_mixin.dart';
import 'mixins/actions_mixin.dart';
import 'mixins/detail_mixin.dart';
import 'mixins/infra_mixin.dart';
import 'mixins/tag_editor_mixin.dart';
import 'rpc_backend_mixin.dart';

class DesktopBackend extends BackendService
    with
        SettingsMixin,
        FeedSearchMixin,
        ActionsMixin,
        DetailMixin,
        InfraMixin,
        TagEditorMixin,
        RpcBackendMixin {
  final String baseUrl;
  final String? executablePath;
  final http.Client _client;
  Process? _process;
  bool _started = false;
  int _idCounter = 1;

  DesktopBackend({this.baseUrl = 'http://127.0.0.1:55009/rpc', this.executablePath, http.Client? client})
    : _client = client ?? http.Client();

  Future<void> _ensureRunning() async {
    if (_started) return;
    _started = true;
    if (executablePath == null) return;
    _process = await Process.start(executablePath!, []);
    _process!.stdout.transform(utf8.decoder).listen((l) => debugPrint('[backend] $l'));
    _process!.stderr.transform(utf8.decoder).listen((l) => debugPrint('[backend:err] $l'));
    _process!.exitCode.then((c) => debugPrint('[backend] exited with code $c'));
    for (var i = 0; i < 30; i++) {
      try { await Future.delayed(const Duration(milliseconds: 200)); if (await rpcCall('ping') == 'pong') return; } catch (_) {}
    }
    debugPrint('[backend] health check timed out');
  }

  @override
  Future<dynamic> rpcCall(String method, [Map<String, dynamic>? params, Duration? timeout]) async {
    final body = jsonEncode({'jsonrpc': '2.0', 'id': _idCounter++, 'method': method, 'params': params ?? {}});
    final res = await _client.post(Uri.parse(baseUrl), headers: {'Content-Type': 'application/json'}, body: body).timeout(
      timeout ?? const Duration(seconds: 60),
    );
    final decoded = jsonDecode(res.body);
    if (decoded['error'] != null) throw Exception(decoded['error'] ?? 'RPC error');
    return decoded['result'];
  }

  @override
  Future<bool> healthCheck() async {
    try {
      await _ensureRunning();
      if (await rpcCall('ping') != 'pong') return false;

      // Find extensions directory: try alongside exe, then CWD/assets/extensions, then CWD/extensions
      String? extDir;
      final exeParent = executablePath != null ? File(executablePath!).parent.path : null;
      if (exeParent != null && await Directory('$exeParent/extensions').exists()) {
        extDir = '$exeParent/extensions';
      } else if (await Directory('${Directory.current.path}/assets/extensions').exists()) {
        extDir = '${Directory.current.path}/assets/extensions';
      } else if (await Directory('${Directory.current.path}/extensions').exists()) {
        extDir = '${Directory.current.path}/extensions';
      }

      if (extDir != null) {
        await rpcCall('initExtensionSystem', {'extensions_dir': extDir, 'data_dir': '$extDir/../ext_data'});
        await rpcCall('loadExtensionsFromDir', {'dir_path': extDir});
      }
      // Windows/Linux have no webview_flutter: route Cloudflare grants
      // through a local loopback HTTP server instead of the spotiflac://
      // deep link. The backend builds challenge URLs with this cb, so the
      // browser returns the grant straight to the app after the captcha.
      // macOS keeps the in-app WebView + spotiflac:// deep link.
      if (!Platform.isMacOS) {
        try {
          if (await DesktopCallbackServer.instance.ensureStarted()) {
            final port = DesktopCallbackServer.instance.port;
            if (port != null) {
              await rpcCall('setSignedSessionCallbackUrl', {
                'url': 'http://127.0.0.1:$port/session-grant',
              });
            }
          }
        } catch (_) {}
      }
      PremiumService().setGithubToken(githubToken);

      // Push saved provider credentials to extensions
      try {
        final cache = sl<SettingsCache>();
        await ProviderCredentialService(this, cache).pushCredentialsOnStartup();
      } catch (_) {}

      return true;
    } catch (_) { return false; }
  }

  void dispose() { _client.close(); _process?.kill(); }
}
