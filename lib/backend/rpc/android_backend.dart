import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../config/secrets.dart';
import '../cache/settings_cache.dart';
import '../services/premium_service.dart';
import '../services/provider_credential_service.dart';
import 'backend_service.dart';
import 'mixins/settings_mixin.dart';
import 'mixins/feed_search_mixin.dart';
import 'mixins/actions_mixin.dart';
import 'mixins/detail_mixin.dart';
import 'mixins/infra_mixin.dart';
import 'mixins/tag_editor_mixin.dart';
import 'rpc_backend_mixin.dart';
import '../../injection.dart' as inj;

class AndroidBackend extends BackendService
    with
        SettingsMixin,
        FeedSearchMixin,
        ActionsMixin,
        DetailMixin,
        InfraMixin,
        TagEditorMixin,
        RpcBackendMixin {
  static const _channel = MethodChannel('com.bitly/backend');
  bool _initialized = false;

  static const _extFiles = <String, List<String>>{
    'amazon': ['index.js', 'manifest.json'],
    'apple-music': ['index.js', 'manifest.json'],
    'deezer': ['index.js', 'manifest.json'],
    'pandora': ['index.js', 'manifest.json'],
    'qobuz-web': ['index.js', 'manifest.json'],
    'soundcloud': ['index.js', 'manifest.json'],
    'spotify-web': ['index.js', 'manifest.json'],
    'tidal-web': ['index.js', 'manifest.json'],
    'ytmusic-spotiflac': ['icon.jpg', 'index.js', 'manifest.json'],
  };

  Future<void> _ensureExtensions(String extDir) async {
    try {
      for (final entry in _extFiles.entries) {
        for (final file in entry.value) {
          try {
            final data = await rootBundle.load('assets/extensions/${entry.key}/$file');
            final dest = File('$extDir/${entry.key}/$file');
            dest.parent.createSync(recursive: true);
            await dest.writeAsBytes(data.buffer.asUint8List());
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  @override
  Future<dynamic> rpcCall(String method, [Map<String, dynamic>? params, Duration? timeout]) async {
    // Defensive timeout so a hung Go RPC can never freeze the UI forever.
    // Callers that legitimately take longer (streaming a full FLAC download)
    // pass a longer timeout explicitly.
    return _channel.invokeMethod(method, params ?? {}).timeout(
      timeout ?? const Duration(seconds: 60),
    );
  }

  @override
  Future<bool> healthCheck() async {
    try {
      if (!_initialized) {
        final dir = await getApplicationDocumentsDirectory();
        final ytDlpPath = '${dir.path}/yt-dlp';
        // Timeouts on every init call so a slow cold start (loading the Go
        // runtime + all extension JS engines) can never hang the splash
        // forever — and so the splash's auto-retry can proceed if a transient
        // first attempt fails.
        // The native side waits up to 120s for the actual Go init (loading the
        // runtime + all extension JS engines), so the Dart timeout must be at
        // least that long — otherwise the first cold-start attempt gives up
        // while Go is still initializing and every splash retry restarts the
        // wait instead of converging on the in-flight init.
        await _channel
            .invokeMethod('initGoBackend', {'app_data_dir': dir.path, 'ytdlp_path': ytDlpPath})
            .timeout(const Duration(seconds: 125));
        PremiumService().setGithubToken(githubToken);
        final extDir = '${dir.path}/extensions';
        await _ensureExtensions(extDir);
        await _channel
            .invokeMethod('initExtensionSystem', {'extensions_dir': extDir, 'data_dir': '${dir.path}/ext_data'})
            .timeout(const Duration(seconds: 30));
        try {
          await _channel
              .invokeMethod('loadExtensionsFromDir', {'dir_path': extDir})
              .timeout(const Duration(seconds: 30));
        } catch (_) {}

        // Sync saved config to Go's in-memory config
        try {
          final dlPath = await inj.sl<SettingsCache>().getDownloadPath();
          if (dlPath != null && dlPath.isNotEmpty) await syncDownloadDir(dlPath);
          final setupData = await inj.sl<SettingsCache>().loadSetupData();
          if (setupData != null) {
            await syncBackendConfig(mode: setupData.mode);
          }
          // Sync the persisted download provider priority so restored sessions
          // keep the user's chosen fallback order (mirrors SpotiFLAC priority).
          final dlPriority = await inj.sl<SettingsCache>().getDownloadProviderPriority();
          if (dlPriority.isNotEmpty) await syncDownloadProviderPriority(dlPriority);
        } catch (_) {}

              // Push saved provider credentials to extensions
        try {
          final cache = inj.sl<SettingsCache>();
          await ProviderCredentialService(this, cache).pushCredentialsOnStartup();
        } catch (_) {}

        _initialized = true;
      }
      return true;
    } catch (_) { return false; }
  }
}
