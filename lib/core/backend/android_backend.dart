import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'backend_service.dart';

class AndroidBackend extends BackendService {
  static const _channel = MethodChannel('com.bitly/backend');
  bool _initialized = false;

  @override
  Future<bool> healthCheck() async {
    try {
      if (!_initialized) {
        final dir = await getApplicationDocumentsDirectory();
        final dbPath = '${dir.path}/bitly.db';
        await _channel.invokeMethod('initGoBackend', {
          'db_path': dbPath,
          'ytdlp_path': '',
        });
        _initialized = true;
      }
      await _channel.invokeMethod('loadAppSettings');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> saveLanguage(String locale) async {
    try {
      await _channel.invokeMethod('saveAppSettings', {
        'value': '{"locale":"$locale"}',
      });
    } catch (_) {}
  }
}
