// Test B del flujo premium en emulador: REINICIO de la app.
//
// Este archivo corre en un PROCESO NUEVO de la app (cada archivo de
// integration_test se instala/lanza por separado), lo que equivale a cerrar
// y reabrir la app. Verifica que el estado premium persistido en drift por
// premium_activate_test.dart:
//   1. Se sincroniza a Go al arrancar (healthCheck → syncPremiumStatus,
//      igual que hace android_backend.dart en producción)
//   2. El gate de descargas (checkDownloadAllowed) permite SIN re-validar
//      el código — la fuente de verdad es drift, no una segunda validación.
//
// CORRER DESPUÉS de premium_activate_test.dart (mismo emulador, sin
// desinstalar la app, para que drift conserve el premium activado).

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:bitly/core/backend_go/backend_android.dart';
import 'package:bitly/app/inyeccion.dart' as inj;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('premium: tras reiniciar, el sync drift→Go mantiene descargas',
      (tester) async {
    await inj.configurarDependencias();
    final backend = BackendAndroid();

    // 1. Init + sync drift→Go automático (lo que hace la app al arrancar).
    final healthy = await backend.healthCheck();
    expect(healthy, isTrue, reason: 'el backend Go debe inicializarse');

    // 2. El estado premium en Go debe estar activo (vino de drift, no de
    //    una nueva validación de código).
    final status = await backend.rpcCall('getEstadoPremium');
    expect(status.toString(), contains('"isPremium":true'),
        reason: 'Go debe haber restaurado premium desde drift: $status');

    // 3. Gate de descargas permite sin re-validar el código.
    final gate = await backend.rpcCall('checkDownloadAllowed');
    expect(gate.toString(), contains('"ok":true'),
        reason: 'el gate debe permitir descargas tras el reinicio: $gate');
  });
}