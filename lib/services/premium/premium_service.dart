/// Servicio de gestión de estado premium de la aplicación.
/// Almacena y recupera el estado premium, códigos de activación,
/// nombre de usuario y prueba gratuita usando [FlutterSecureStorage].
/// Proporciona restauración automática del estado al iniciar la app.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum PremiumStatus { none, premium, freeTrial, expired }

class PremiumService {
  static final _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      migrateOnAlgorithmChange: true,
    ),
  );
  static const _keyPremium = 'bitly_premium';
  static const _keyPremiumUntil = 'bitly_premium_until';
  static const _keyUsername = 'bitly_username';
  static const _keyPremiumCode = 'bitly_premium_code';

  static Future<bool> isPremium() async {
    try {
      final status = await getDetailedStatus();
      return status == PremiumStatus.premium || status == PremiumStatus.freeTrial;
    } catch (e) {
      // If secure storage fails, treat as non-premium
      return false;
    }
  }

  static Future<PremiumStatus> getDetailedStatus() async {
    try {
      final val = await _storage.read(key: _keyPremium);
      if (val != 'true') return PremiumStatus.none;

      final untilStr = await _storage.read(key: _keyPremiumUntil);
      if (untilStr == null || untilStr == '0') return PremiumStatus.premium;

      final until = int.tryParse(untilStr) ?? 0;
      if (until > 0 && DateTime.now().millisecondsSinceEpoch > until) {
        return PremiumStatus.expired;
      }
      return PremiumStatus.freeTrial;
    } catch (e) {
      // If secure storage fails, treat as non-premium
      return PremiumStatus.none;
    }
  }

  static Future<String?> getSavedUsername() async {
    try {
      return await _storage.read(key: _keyUsername);
    } catch (e) {
      return null;
    }
  }

  static Future<String?> getSavedPremiumCode() async {
    try {
      return await _storage.read(key: _keyPremiumCode);
    } catch (e) {
      return null;
    }
  }

  static bool _esCodigoValido(String codigo) {
    // Simple validation: premium codes should be 16-20 characters, alphanumeric with dashes
    if (codigo.length < 16 || codigo.length > 20) return false;
    return RegExp(r'^[A-Z0-9-]+$').hasMatch(codigo.toUpperCase());
  }

  static bool validarCodigo(String codigo) {
    return _esCodigoValido(codigo.trim());
  }

  static Future<bool> activateCode(String codigo) async {
    try {
      final codigoLimpio = codigo.trim();
      if (!_esCodigoValido(codigoLimpio)) return false;
      await _storage.write(key: _keyPremium, value: 'true');
      await _storage.write(key: _keyPremiumUntil, value: '0');
      await _storage.write(key: _keyPremiumCode, value: codigoLimpio);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> startFreeTrial() async {
    try {
      final until = DateTime.now()
          .add(const Duration(hours: 12))
          .millisecondsSinceEpoch;
      await _storage.write(key: _keyPremium, value: 'true');
      await _storage.write(key: _keyPremiumUntil, value: until.toString());
      await _storage.delete(key: _keyPremiumCode);
    } catch (e) {
      // Ignore errors
    }
  }

  static Future<void> saveUsername(String name) async {
    try {
      await _storage.write(key: _keyUsername, value: name);
    } catch (e) {
      // Ignore errors
    }
  }

  static Future<bool> tryAutoRestore() async {
    try {
      final codigo = await getSavedPremiumCode();
      if (codigo != null && _esCodigoValido(codigo)) {
        await _storage.write(key: _keyPremium, value: 'true');
        await _storage.write(key: _keyPremiumUntil, value: '0');
        return true;
      }
      final username = await getSavedUsername();
      if (username == null) return false;
      return await isPremium();
    } catch (e) {
      return false;
    }
  }

  static Future<int> getPremiumUntil() async {
    try {
      final untilStr = await _storage.read(key: _keyPremiumUntil);
      return int.tryParse(untilStr ?? '0') ?? 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<void> clearSavedPremiumState() async {
    try {
      await _storage.delete(key: _keyPremium);
      await _storage.delete(key: _keyPremiumUntil);
      await _storage.delete(key: _keyPremiumCode);
      await _storage.delete(key: _keyUsername);
    } catch (e) {
      // Ignore errors
    }
  }
}
