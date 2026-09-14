import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CuentaServicio {
  final String? token;
  final String? refreshToken;
  final String? userId;
  final DateTime? expiresAt;

  CuentaServicio({
    this.token,
    this.refreshToken,
    this.userId,
    this.expiresAt,
  });

  factory CuentaServicio.fromJson(Map<String, dynamic> json) {
    return CuentaServicio(
      token: json['token'],
      refreshToken: json['refresh_token'],
      userId: json['user_id']?.toString(),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
    );
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isExpiringSoon {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!.subtract(Duration(days: 2)));
  }
}

class PendingAction {
  final int id;
  final String service;
  final String actionType;
  final String title;
  final String? description;
  final String? url;
  final String? extraJson;
  final String status;
  final DateTime createdAt;
  final DateTime? expiresAt;

  PendingAction({
    required this.id,
    required this.service,
    required this.actionType,
    required this.title,
    this.description,
    this.url,
    this.extraJson,
    required this.status,
    required this.createdAt,
    this.expiresAt,
  });

  factory PendingAction.fromJson(Map<String, dynamic> json) {
    return PendingAction(
      id: json['id'],
      service: json['service'],
      actionType: json['action_type'],
      title: json['title'],
      description: json['description'],
      url: json['url'],
      extraJson: json['extra_json'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
    );
  }

  Map<String, dynamic>? get extraData {
    if (extraJson == null) return null;
    return jsonDecode(extraJson!);
  }
}

class ServicioCuentasCentral {
  static const String _baseUrl = 'https://tu-servidor.up.railway.app';
  static const String _deviceIdKey = 'bitly_device_id';
  static const String _accountsKey = 'bitly_central_accounts';

  String? _deviceId;
  Map<String, CuentaServicio> _accounts = {};

  static final ServicioCuentasCentral _instance = ServicioCuentasCentral._internal();
  factory ServicioCuentasCentral() => _instance;
  ServicioCuentasCentral._internal();

  Future<void> init() async {
    _deviceId = await _getOrCreateDeviceId();
    await _loadCachedAccounts();
    await _registerDevice();
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    return deviceId;
  }

  Future<void> _loadCachedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString(_accountsKey);

    if (accountsJson != null) {
      final Map<String, dynamic> decoded = jsonDecode(accountsJson);
      _accounts = decoded.map(
        (key, value) => MapEntry(key, CuentaServicio.fromJson(value)),
      );
    }
  }

  Future<void> _saveCachedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = _accounts.map(
      (key, value) => MapEntry(key, {
        'token': value.token,
        'refresh_token': value.refreshToken,
        'user_id': value.userId,
        'expires_at': value.expiresAt?.toIso8601String(),
      }),
    );
    await prefs.setString(_accountsKey, jsonEncode(accountsJson));
  }

  Future<void> _registerDevice() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'device_id': _deviceId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accounts = data['accounts'] as Map<String, dynamic>;

        accounts.forEach((service, accountData) {
          _accounts[service] = CuentaServicio.fromJson(accountData);
        });

        await _saveCachedAccounts();
      }
    } catch (e) {
      print('Error registering device: $e');
    }
  }

  Future<CuentaServicio?> getCuenta(String service) async {
    final cuenta = _accounts[service];

    if (cuenta != null && !cuenta.isExpired && !cuenta.isExpiringSoon) {
      return cuenta;
    }

    return await _refreshToken(service);
  }

  Future<CuentaServicio?> _refreshToken(String service) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/token?device_id=$_deviceId&service=$service'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final cuenta = CuentaServicio.fromJson(data);

        _accounts[service] = cuenta;
        await _saveCachedAccounts();

        return cuenta;
      }
    } catch (e) {
      print('Error refreshing token: $e');
    }

    return null;
  }

  Future<Map<String, CuentaServicio>> getAllAccounts() async {
    final result = <String, CuentaServicio>{};

    for (final service in ['qobuz', 'tidal', 'deezer']) {
      final cuenta = await getCuenta(service);
      if (cuenta != null) {
        result[service] = cuenta;
      }
    }

    return result;
  }

  Future<bool> hasValidAccount(String service) async {
    final cuenta = await getCuenta(service);
    return cuenta != null && !cuenta.isExpired;
  }

  Future<List<PendingAction>> getPendingActions() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/pending'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => PendingAction.fromJson(item)).toList();
      }
    } catch (e) {
      print('Error getting pending actions: $e');
    }

    return [];
  }

  Future<void> completePendingAction(int actionId) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/pending'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action_id': actionId}),
      );
    } catch (e) {
      print('Error completing pending action: $e');
    }
  }

  Future<void> submitDeezerARL(String arl) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/deezer/arl'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_id': _deviceId,
          'arl': arl,
        }),
      );
    } catch (e) {
      print('Error submitting Deezer ARL: $e');
    }
  }
}
