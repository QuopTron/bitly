import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/feed_models.dart';
import '../models/setup_data.dart';
import '../models/premium_status.dart';
import 'backend_service.dart';
import 'backend_helpers.dart';

const _githubToken = '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';

class IOSBackend extends BackendService {
  static const _channel = MethodChannel('com.bitly/backend');
  bool _initialized = false;

  @override
  Future<bool> healthCheck() async {
    try {
      if (!_initialized) {
        final dir = await _channel.invokeMethod('getApplicationDocumentsDirectory');
        final dbPath = '$dir/bitly.db';
        await _channel.invokeMethod('initGoBackend', {'db_path': dbPath});
        try {
          await _channel.invokeMethod('setGithubToken', {'token': _githubToken});
        } catch (_) {}
        await _channel.invokeMethod('loadExtensionsFromDir', {'dir_path': '$dir/extensions'});
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
      await _channel.invokeMethod('saveAppSettings', {'value': '{"locale":"$locale"'});
    } catch (_) {}
  }

  @override
  Future<SetupData?> loadSetupData() async {
    try {
      return BackendHelpers.parseSetupData(await _channel.invokeMethod('loadAppSettings'));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> completeSetup({required String locale, required String mode, required String username, String? premiumCode}) async {
    await _channel.invokeMethod('saveAppSettings', {
      'value': jsonEncode(BackendHelpers.buildSetupData(locale: locale, mode: mode, username: username, premiumCode: premiumCode)),
    });
  }

  @override
  Future<String?> validatePremiumCode(String code) async {
    try {
      return BackendHelpers.parseValidationResult(await _channel.invokeMethod('validarCodigoPremium', {'codigo': code}));
    } catch (e) {
      return e.toString();
    }
  }

  @override
  Future<void> activatePremium(String code) async {
    await _channel.invokeMethod('setUserPremiumV2JSON', {'tier': 'premium', 'premium_until': 0});
  }

  @override
  Future<PremiumStatus> getPremiumStatus() async {
    try {
      return BackendHelpers.parsePremiumStatus(await _channel.invokeMethod('getUserPremiumV2JSON'));
    } catch (_) {
      return const PremiumStatus(tier: 'free', premiumUntil: 0, activo: false);
    }
  }

  @override
  Future<List<FeedSection>> getHomeFeed({String locale = 'en'}) async {
    try {
      return BackendHelpers.parseFeedSections(await _channel.invokeMethod('getHomeFeed', {'locale': locale}));
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
      return BackendHelpers.parseSearchResults(await _channel.invokeMethod('search', params));
    } catch (_) {
      return [];
    }
  }
}
