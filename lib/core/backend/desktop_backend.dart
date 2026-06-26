import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/feed_models.dart';
import '../models/setup_data.dart';
import '../models/premium_status.dart';
import 'backend_service.dart';
import 'backend_helpers.dart';

const _githubToken = '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';

class DesktopBackend extends BackendService {
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
      try { await Future.delayed(const Duration(milliseconds: 200)); if (await _call('ping') == 'pong') return; } catch (_) {}
    }
    debugPrint('[backend] health check timed out');
  }

  Future<dynamic> _call(String method, [Map<String, dynamic>? params]) async {
    final body = jsonEncode({'jsonrpc': '2.0', 'id': _idCounter++, 'method': method, 'params': params ?? {}});
    final res = await _client.post(Uri.parse(baseUrl), headers: {'Content-Type': 'application/json'}, body: body);
    final decoded = jsonDecode(res.body);
    if (decoded['error'] != null) throw Exception(decoded['error'] ?? 'RPC error');
    return decoded['result'];
  }

  @override
  Future<bool> healthCheck() async {
    try {
      await _ensureRunning();
      if (await _call('ping') != 'pong') return false;
      final exeDir = executablePath != null ? File(executablePath!).parent.path : Directory.current.path;
      await _call('initExtensionSystem', {'extensions_dir': '$exeDir/extensions', 'data_dir': '$exeDir/ext_data'});
      await _call('loadExtensionsFromDir', {'dir_path': '$exeDir/extensions'});
      try { await _call('setGithubToken', {'token': _githubToken}); } catch (_) {}
      return true;
    } catch (_) { return false; }
  }

  @override
  Future<void> saveLanguage(String locale) async {
    try { await _call('saveAppSettings', {'value': '{"locale":"$locale"}'}); } catch (_) {}
  }

  @override
  Future<SetupData?> loadSetupData() async {
    try { return BackendHelpers.parseSetupData(await _call('loadAppSettings')); } catch (_) { return null; }
  }

  @override
  Future<void> completeSetup({required String locale, required String mode, required String username, String? premiumCode}) async {
    await _call('saveAppSettings', {'value': jsonEncode(BackendHelpers.buildSetupData(locale: locale, mode: mode, username: username, premiumCode: premiumCode))});
  }

  @override
  Future<String?> validatePremiumCode(String code) async {
    try { return BackendHelpers.parseValidationResult(await _call('validarCodigoPremium', {'codigo': code})); } catch (e) { return e.toString(); }
  }

  @override
  Future<void> activatePremium(String code) async {
    await _call('setUserPremiumV2JSON', {'tier': 'premium', 'premium_until': 0});
  }

  @override
  Future<PremiumStatus> getPremiumStatus() async {
    try { return BackendHelpers.parsePremiumStatus(await _call('getUserPremiumV2JSON')); } catch (_) {
      return const PremiumStatus(tier: 'free', premiumUntil: 0, activo: false);
    }
  }

  @override
  Future<List<FeedSection>> getHomeFeed({String locale = 'en'}) async {
    try { return BackendHelpers.parseFeedSections(await _call('getHomeFeed', {'locale': locale})); } catch (_) { return []; }
  }

  @override
  Future<List<FeedItem>> search({required String query, String source = '', String type = '', int limit = 20}) async {
    try {
      final params = <String, dynamic>{'query': query, 'limit': limit};
      if (source.isNotEmpty) params['source'] = source;
      if (type.isNotEmpty) params['type'] = type;
      return BackendHelpers.parseSearchResults(await _call('search', params));
    } catch (_) { return []; }
  }

  void dispose() { _client.close(); _process?.kill(); }
}
