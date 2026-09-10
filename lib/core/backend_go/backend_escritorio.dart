// ─────────────────────────────────────────────────────────────
// backend_escritorio.dart — Implementación del backend Go para
// escritorio (Windows/Linux/macOS) vía HTTP contra un proceso local
// (jsonrpc 2.0 en http://127.0.0.1:55009/rpc).
// Se conecta con: backend_go (mixins RPC) + app/inyeccion (caches).
// Parte del flujo: arranque (healthCheck → spawn del binario Go).
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/secretos.dart';
import '../../app/inyeccion.dart';
import '../cache/cache_premium.dart';
import '../cache/cache_ajustes.dart';
import '../servicios/servicio_credenciales_proveedor.dart';
import '../servicios/servidor_callback_escritorio.dart';
import 'contrato_backend.dart';
import 'mixins/acciones_mixin.dart';
import 'mixins/ajustes_mixin.dart';
import 'mixins/detalle_mixin.dart';
import 'mixins/editor_etiquetas_mixin.dart';
import 'mixins/feed_busqueda_mixin.dart';
import 'mixins/infra_mixin.dart';
import 'mixins/premium_mixin.dart';
import 'mixins/sesiones_acciones_mixin.dart';
import 'mixins/sesiones_firmadas_mixin.dart';
import 'mixins/sesiones_keepalive_mixin.dart';
import 'rpc_backend_mixin.dart';

class BackendEscritorio extends BackendService
    with
        AjustesMixin,
        FeedBusquedaMixin,
        AccionesMixin,
        DetalleMixin,
        InfraMixin,
        PremiumMixin,
        EditorEtiquetasMixin,
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
    // `pid` de dart:io nunca es null en un proceso real; el backend Go lo usa
    // para vigilar que la app siga viva y salir si se cierra.
    _proceso = await Process.start(rutaEjecutable!, [pid.toString()]);
    _proceso!.stdout.transform(utf8.decoder).listen((l) => debugPrint('[backend] $l'));
    _proceso!.stderr.transform(utf8.decoder).listen((l) => debugPrint('[backend:err] $l'));
    _proceso!.exitCode.then((c) => debugPrint('[backend] salió con código $c'));
    for (var i = 0; i < 30; i++) {
      try {
        await Future.delayed(const Duration(milliseconds: 200));
        if (await rpcCall('ping') == 'pong') return;
      } catch (_) {}
    }
    debugPrint('[backend] health check agotó el tiempo');
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

      // Busca el directorio de extensiones: junto al exe, luego CWD/assets,
      // luego CWD/extensions.
      String? dirExt;
      final padreExe = rutaEjecutable != null ? File(rutaEjecutable!).parent.path : null;
      if (padreExe != null && await Directory('$padreExe/extensions').exists()) {
        dirExt = '$padreExe/extensions';
      } else if (await Directory('${Directory.current.path}/assets/extensions').exists()) {
        dirExt = '${Directory.current.path}/assets/extensions';
      } else if (await Directory('${Directory.current.path}/extensions').exists()) {
        dirExt = '${Directory.current.path}/extensions';
      }

      if (dirExt != null) {
        await rpcCall('initExtensionSystem', {'extensions_dir': dirExt, 'data_dir': '$dirExt/../ext_data'});
        await rpcCall('loadExtensionsFromDir', {'dir_path': dirExt});
      }
      // Sin webview (Win/Linux): grants Cloudflare por servidor HTTP loopback
      // local en vez del deep link spotiflac:// (macOS usa el WebView in-app).
      if (!Platform.isMacOS) {
        try {
          if (await ServidorCallbackEscritorio.instance.garantizarIniciado()) {
            final puerto = ServidorCallbackEscritorio.instance.puerto;
            if (puerto != null) {
              await rpcCall('setSignedSessionCallbackUrl', {
                'url': 'http://127.0.0.1:$puerto/session-grant',
              });
            }
          }
        } catch (_) {}
      }
      await setPremiumGithubToken(tokenGithub);

      // Sincroniza el estado premium (drift) a Go para que el gate de
      // descargas respete códigos ya activados en una sesión previa.
      try {
        final premium = await sl<CachePremium>().getEstadoPremium();
        await syncPremiumStatus(
          isPremium: premium.esPremium,
          tier: premium.tier,
          expiresAt: premium.premiumHasta,
        );
      } catch (_) {}

      // Empuja las credenciales guardadas de proveedores a las extensiones.
      try {
        final cache = sl<CacheAjustes>();
        await ServicioCredencialesProveedor(this, cache).empujarCredencialesAlArrancar();
      } catch (_) {}

      return true;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _cliente.close();
    _proceso?.kill();
  }
}