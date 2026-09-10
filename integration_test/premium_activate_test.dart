// Test A del flujo premium en emulador: ACTIVAR un código.
//
// Flujo real verificado (igual que hace la app):
//   1. init del backend Go real (healthCheck → initGoBackend)
//   2. setPremiumGithubToken('') → se salta el registro remoto de GitHub
//      (el registro codes.json es un servicio externo del usuario que no se
//      puede tocar desde un test; la validación contra ese registro ya está
//      cubierta por unit tests Go con el formato exacto)
//   3. validatePremiumCode(código) → valida estructura + firma en Go
//   4. CachePremium.activarPremium → persiste premium en drift (365 días)
//   5. checkDownloadAllowed → el gate permite descargas
//
// CORRER EN ORDEN: primero este archivo, luego premium_restart_test.dart
// (que verifica el reinicio en un proceso nuevo de la app).

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:bitly/core/cache/cache_premium.dart';
import 'package:bitly/core/backend_go/backend_android.dart';
import 'package:bitly/app/inyeccion.dart' as inj;

/// Replica exacta del generador de códigos del lado emisor (PremiumService
/// Dart / generarCodeApp en Go): payload {p: palabra, e: expiración} →
/// base64url sin padding → HMAC-SHA256(dataB64.palabra, secret) → base64url.
String generarCodigoPremium(String word, int expiresAt) {
  final payload = jsonEncode({'p': word, 'e': expiresAt});
  final dataB64 =
      base64Url.encode(utf8.encode(payload)).replaceAll('=', '');
  final hmac = Hmac(sha256, utf8.encode('bitly_secret_key_v1'));
  final sig = base64Url
      .encode(hmac.convert(utf8.encode('$dataB64.$word')).bytes)
      .replaceAll('=', '');
  return '$dataB64.$sig';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('premium: activar código válido y gate permite descargas',
      (tester) async {
    await inj.configurarDependencias();
    final backend = BackendAndroid();

    // 1. Init real del backend Go en el dispositivo.
    final healthy = await backend.healthCheck();
    expect(healthy, isTrue, reason: 'el backend Go debe inicializarse');

    // 2. Sin token de GitHub → el registro remoto se salta (solo estructura).
    await backend.setPremiumGithubToken('');

    // 3. Código válido con palabra autorizada, expira en ~2030.
    final expiresAt = DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/ 1000;
    final code = generarCodigoPremium('pablo', expiresAt);
    final error = await backend.validatePremiumCode(code);
    expect(error, isNull, reason: 'código válido no debe devolver error: $error');

    // 4. Persistir en drift igual que hace la app tras validar.
    await inj.sl<CachePremium>().activarPremium(code);
    final stored = await inj.sl<CachePremium>().getEstadoPremium();
    expect(stored.activo, isTrue, reason: 'drift debe guardar premium');
    expect(stored.tier, 'premium');

    // 5. Gate de descargas en Go debe permitir.
    final gate = await backend.rpcCall('checkDownloadAllowed');
    expect(gate.toString(), contains('"ok":true'),
        reason: 'gate debe permitir descargas con premium activo: $gate');
  });
}