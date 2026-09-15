// ─────────────────────────────────────────────────────────────
// backend_escritorio.dart — Implementación del backend Go para
// escritorio (Windows/Linux/macOS) vía HTTP contra un proceso local
// (jsonrpc 2.0 en http://127.0.0.1:55009/rpc). Las rutinas de arranque
// (CWD, extensiones, callback, premium) viven en
// backend_escritorio_arranque.dart.
// Se conecta con: backend_go (mixins RPC) + app/inyeccion (caches).
// Parte del flujo: arranque (healthCheck → spawn del binario Go).
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../app/inyeccion.dart';
import '../../../config/secretos.dart';
import '../../cache/almacenes/cache_ajustes.dart';
import '../../cache/almacenes/cache_premium.dart';
import '../../servicios/oauth/servidor_callback_escritorio.dart';
import '../../servicios/proveedores/servicio_credenciales_proveedor.dart';
import '../mixins/acciones_mixin.dart';
import '../mixins/ajustes_mixin.dart';
import '../mixins/biblioteca_local_mixin.dart';
import '../mixins/detalle_mixin.dart';
import '../mixins/editor_etiquetas_mixin.dart';
import '../mixins/enlaces_mixin.dart';
import '../mixins/feed_busqueda_mixin.dart';
import '../mixins/infra_mixin.dart';
import '../mixins/premium_mixin.dart';
import '../mixins/sesiones_acciones_mixin.dart';
import '../mixins/sesiones_firmadas_mixin.dart';
import '../mixins/sesiones_keepalive_mixin.dart';
import '../nucleo/contrato_backend.dart';
import '../nucleo/rpc_backend_mixin.dart';

part 'backend_escritorio_arranque.dart';

class BackendEscritorio extends BackendService
    with
        AjustesMixin,
        FeedBusquedaMixin,
        AccionesMixin,
        DetalleMixin,
        InfraMixin,
        BibliotecaLocalMixin,
        PremiumMixin,
        EditorEtiquetasMixin,
        EnlacesMixin,
        SesionesFirmadasMixin,
        SesionesAccionesMixin,
        SesionesKeepaliveMixin,
        RpcBackendMixin {
  final String baseUrl;
  final String? rutaEjecutable;
  final http.Client _cliente;
  Process? _proceso;
  bool _iniciado = false;
  int _contadorId = 1;

  BackendEscritorio({this.baseUrl = 'http://127.0.0.1:55009/rpc', this.rutaEjecutable, http.Client? cliente})
      : _cliente = cliente ?? http.Client();

  Future<void> _garantizarEnMarcha() async {
    if (_iniciado) return;
    _iniciado = true;
    if (rutaEjecutable == null) return;
    // En escritorio se pasa el PID de la app como argumento: el backend Go
    // vigila ese PID y sale solo si la app se cierra (sin dejar huérfanos).
    // En móvil no hay proceso separado (gomobile embebido) — no aplica.
    final cwd = await _cwdEscribible();
    _proceso = await Process.start(rutaEjecutable!, [pid.toString()],
        workingDirectory: cwd);
    _proceso!.stdout.transform(utf8.decoder).listen((l) => debugPrint('[backend] $l'));
    _proceso!.stderr.transform(utf8.decoder).listen((l) => debugPrint('[backend:err] $l'));
    _proceso!.exitCode.then((c) => debugPrint('[backend] salió con código $c'));
    for (var i = 0; i < 60; i++) {
      try {
        await Future.delayed(const Duration(milliseconds: 200));
        if (await rpcCall('ping') == 'pong') return;
      } catch (e) {
        debugPrint("[Backend] $e");
      }
    }
    debugPrint('[backend] health check agotó el tiempo (12s) — el binario Go no arrancó');
  }

  @override
  Future<dynamic> rpcCall(String method, [Map<String, dynamic>? params, Duration? timeout]) async {
    final body = jsonEncode({'jsonrpc': '2.0', 'id': _contadorId++, 'method': method, 'params': params ?? {}});
    final res = await _cliente.post(Uri.parse(baseUrl), headers: {'Content-Type': 'application/json'}, body: body).timeout(
      timeout ?? const Duration(seconds: 60),
    );
    final decodificado = jsonDecode(res.body);
    if (decodificado['error'] != null) throw Exception(decodificado['error'] ?? 'Error RPC');
    return decodificado['result'];
  }

  @override
  Future<bool> healthCheck() async {
    try {
      await _garantizarEnMarcha();
      if (await rpcCall('ping') != 'pong') return false;

      // ── Post-ping init: extensiones, premium, callback ──
      // Todo lo que sigue es NO-BLOQUEANTE: se lanza en background y la
      // app entra al home de inmediato. Si las extensiones tardan en cargar,
      // el feed mostrará "cargando" pero la UI responde. El keepalive /
      // sync de arranque reintentará si algo falla.
      _initPostPing();

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Init post-ping en background: extensiones, premium, callback, credenciales.
  /// Lanzado desde healthCheck sin await para no bloquear el splash.
  Future<void> _initPostPing() async {
    try {
      final dirExt = await _buscarDirExtensiones(rutaEjecutable);
      if (dirExt != null) await _initExtensiones(this, dirExt);
      if (!Platform.isMacOS) await _initCallback(this);
      await setPremiumGithubToken(tokenGithub);
      await _initPremiumCredenciales(this);
    } catch (e) {
      debugPrint('[backend] _initPostPing error: $e');
    }
  }

  void dispose() {
    _cliente.close();
    _proceso?.kill();
  }
}
