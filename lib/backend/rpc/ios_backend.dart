import 'package:flutter/services.dart';
import '../../config/secrets.dart';
import '../cache/settings_cache.dart';
import '../services/premium_service.dart';
import 'backend_service.dart';
import 'mixins/settings_mixin.dart';
import 'mixins/feed_search_mixin.dart';
import 'mixins/actions_mixin.dart';
import 'mixins/detail_mixin.dart';
import 'mixins/infra_mixin.dart';
import 'rpc_backend_mixin.dart';
import '../../injection.dart' as inj;

class IOSBackend extends BackendService
    with
        SettingsMixin,
        FeedSearchMixin,
        ActionsMixin,
        DetailMixin,
        InfraMixin,
        RpcBackendMixin {
  static const _channel = MethodChannel('com.bitly/backend');
  bool _initialized = false;

  @override
  Future<dynamic> rpcCall(String method, [Map<String, dynamic>? params, Duration? timeout]) async {
    final result = await _channel.invokeMethod(method, params ?? {}).timeout(
      timeout ?? const Duration(seconds: 60),
    );
    return result;
  }

  @override
  Future<bool> healthCheck() async {
    try {
      if (!_initialized) {
        final dir = await _channel.invokeMethod('getApplicationDocumentsDirectory');
        await _channel.invokeMethod('initGoBackend', {'app_data_dir': dir});
        PremiumService().setGithubToken(githubToken);
        await _channel.invokeMethod('loadExtensionsFromDir', {'dir_path': '$dir/extensions'});

        // Sync saved config to Go's in-memory config
        try {
          final dlPath = await inj.sl<SettingsCache>().getDownloadPath();
          if (dlPath != null && dlPath.isNotEmpty) await syncDownloadDir(dlPath);
          final setupData = await inj.sl<SettingsCache>().loadSetupData();
          if (setupData != null) {
            await syncBackendConfig(mode: setupData.mode);
          }
        } catch (_) {}

        _initialized = true;
      }
      return true;
    } catch (_) { return false; }
  }
}
