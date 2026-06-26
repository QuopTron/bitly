import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/feed_models.dart';
import '../models/setup_data.dart';
import '../models/premium_status.dart';
import 'backend_service.dart';
import 'backend_helpers.dart';

const _githubToken = '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';

class AndroidBackend extends BackendService {
  static const _channel = MethodChannel('com.bitly/backend');
  bool _initialized = false;

  /// Known bundled extensions and their files under assets/extensions/.
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

  /// Copies bundled extensions from Flutter assets into [extDir] on first run.
  Future<void> _ensureExtensions(String extDir) async {
    try {
      final root = Directory(extDir);
      if (root.existsSync()) return;
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
  Future<bool> healthCheck() async {
    try {
      if (!_initialized) {
        final dir = await getApplicationDocumentsDirectory();
        final dbPath = '${dir.path}/bitly.db';
        final ytDlpPath = '${dir.path}/yt-dlp';
        await _channel.invokeMethod('initGoBackend', {
          'db_path': dbPath,
          'ytdlp_path': ytDlpPath,
        });

        try {
          await _channel.invokeMethod('setGithubToken', {
            'token': _githubToken,
          });
        } catch (_) {}

        final extDir = '${dir.path}/extensions';
        await _ensureExtensions(extDir);

        await _channel.invokeMethod('initExtensionSystem', {
          'extensions_dir': extDir,
          'data_dir': '${dir.path}/ext_data',
        });
        try {
          await _channel.invokeMethod('loadExtensionsFromDir', {
            'dir_path': extDir,
          });
        } catch (_) {}
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

  @override
  Future<SetupData?> loadSetupData() async {
    try {
      final result = await _channel.invokeMethod('loadAppSettings');
      return BackendHelpers.parseSetupData(result);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> completeSetup({
    required String locale,
    required String mode,
    required String username,
    String? premiumCode,
  }) async {
    final data = BackendHelpers.buildSetupData(
      locale: locale,
      mode: mode,
      username: username,
      premiumCode: premiumCode,
    );
    await _channel.invokeMethod('saveAppSettings', {
      'value': jsonEncode(data),
    });
  }

  @override
  Future<String?> validatePremiumCode(String code) async {
    try {
      final result = await _channel
          .invokeMethod('validarCodigoPremium', {'codigo': code});
      return BackendHelpers.parseValidationResult(result);
    } catch (e) {
      return e.toString();
    }
  }

  @override
  Future<void> activatePremium(String code) async {
    await _channel.invokeMethod('setUserPremiumV2JSON', {
      'tier': 'premium',
      'premium_until': 0,
    });
  }

  @override
  Future<PremiumStatus> getPremiumStatus() async {
    try {
      final result = await _channel.invokeMethod('getUserPremiumV2JSON');
      return BackendHelpers.parsePremiumStatus(result);
    } catch (_) {
      return const PremiumStatus(tier: 'free', premiumUntil: 0, activo: false);
    }
  }

  @override
  Future<List<FeedSection>> getHomeFeed({String locale = 'en'}) async {
    try {
      final result = await _channel.invokeMethod('getHomeFeed', {
        'locale': locale,
      });
      return BackendHelpers.parseFeedSections(result);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<FeedItem>> search({required String query, String source = '', String type = '', int limit = 20}) async {
    try {
      final params = <String, dynamic>{'query': query, 'limit': limit};
      if (source.isNotEmpty) params['source'] = source;
      if (type.isNotEmpty) params['type'] = type;
      final result = await _channel.invokeMethod('search', params);
      return BackendHelpers.parseSearchResults(result);
    } catch (_) {
      return [];
    }
  }
}
