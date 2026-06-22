import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'backend_service.dart';

class DesktopBackend extends BackendService {
  final String baseUrl;
  final String? executablePath;
  final http.Client _client;
  Process? _process;
  bool _started = false;
  int _idCounter = 1;

  DesktopBackend({
    this.baseUrl = 'http://127.0.0.1:55009/rpc',
    this.executablePath,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<void> _ensureRunning() async {
    if (_started) return;
    _started = true;

    if (executablePath == null) return;

    _process = await Process.start(executablePath!, []);

    _process!.stdout
        .transform(utf8.decoder)
        .listen((line) => debugPrint('[backend] $line'));

    _process!.stderr
        .transform(utf8.decoder)
        .listen((line) => debugPrint('[backend:err] $line'));

    _process!.exitCode.then((code) {
      debugPrint('[backend] exited with code $code');
    });

    for (var i = 0; i < 30; i++) {
      try {
        await Future.delayed(const Duration(milliseconds: 200));
        final res = await _call('ping');
        if (res == 'pong') return;
      } catch (_) {}
    }

    debugPrint('[backend] health check timed out');
  }

  Future<dynamic> _call(String method, [Map<String, dynamic>? params]) async {
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'id': _idCounter++,
      'method': method,
      'params': params ?? {},
    });
    final response = await _client.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    final decoded = jsonDecode(response.body);
    if (decoded['error'] != null) {
      throw Exception(decoded['error'] ?? 'RPC error');
    }
    return decoded['result'];
  }

  @override
  Future<bool> healthCheck() async {
    try {
      await _ensureRunning();
      final res = await _call('ping');
      return res == 'pong';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> saveLanguage(String locale) async {
    try {
      await _call('saveAppSettings', {'value': '{"locale":"$locale"}'});
    } catch (_) {}
  }

  void dispose() {
    _client.close();
    _process?.kill();
  }
}
