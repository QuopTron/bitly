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

import '../../../config/secretos.dart';
import '../../../app/inyeccion.dart';
import '../../cache/almacenes/cache_premium.dart';
import '../../cache/almacenes/cache_ajustes.dart';
import '../../servicios/proveedores/servicio_credenciales_proveedor.dart';
import '../../servicios/oauth/servidor_callback_escritorio.dart';
import '../nucleo/contrato_backend.dart';
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
import '../nucleo/rpc_backend_mixin.dart';

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
    // `pid` de dart:io nunca es null en un proceso real; el backend Go lo usa
    // para vigilar que la app siga viva y salir si se cierra.
    //
    // CWD escribible: en macOS una app GUI lanzada por Finder/Dock hereda "/"
    // como directorio de trabajo (solo lectura) y el gestor de bins (yt-dlp)
    // + los stores de extensiones fallarían al crear carpetas ahí. Apuntamos
    // el CWD al directorio de datos de la app (mismo rol que app_data_dir en
    // Android). En Windows/Linux el exe ya vive en una carpeta escribible.
    String? cwd;
    if (Platform.isMacOS) {
      try {
        final home = Platform.environment['HOME'] ?? '';
        final dirDatos = '$home/Library/Application Support/com.example.bitly';
        await Directory(dirDatos).create(recursive: true);
        cwd = dirDatos;
      } catch (_) {}
    }
    _proceso = await Process.start(rutaEjecutable!, [pid.toString()],
        workingDirectory: cwd);
    _proceso!.stdout.transform(utf8.decoder).listen((l) => debugPrint('[backend] $l'));
    _proceso!.stderr.transform(utf8.decoder).listen((l) => debugPrint('[backend:err] $l'));
    _proceso!.exitCode.then((c) => debugPrint('[backend] salió con código $c'));
    for (var i = 0; i < 60; i++) {
      try {
        await Future.delayed(const Duration(milliseconds: 200));
        if (await rpcCall('ping') == 'pong') return;
      } catch (_) {}
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
        try {
          var dirDatos = '$dirExt/../ext_data';
          if (Platform.isMacOS) {
            final home = Platform.environment['HOME'] ?? '';
            dirDatos = '$home/Library/Application Support/com.example.bitly/ext_data';
            await Directory(dirDatos).create(recursive: true);
          }
          await rpcCall('initExtensionSystem', {'extensions_dir': dirExt, 'data_dir': dirDatos});
          await rpcCall('loadExtensionsFromDir', {'dir_path': dirExt});
        } catch (e) {
          debugPrint('[backend] init de extensiones falló (no fatal): $e');
        }
      }

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

      try {
        final premium = await sl<CachePremium>().getEstadoPremium();
        await syncPremiumStatus(
          isPremium: premium.esPremium,
          tier: premium.tier,
          expiresAt: premium.premiumHasta,
        );
      } catch (_) {}

      try {
        final cache = sl<CacheAjustes>();
        await ServicioCredencialesProveedor(this, cache).empujarCredencialesAlArrancar();
      } catch (_) {}
    } catch (e) {
      debugPrint('[backend] _initPostPing error: $e');
    }
  }

  void dispose() {
    _cliente.close();
    _proceso?.kill();
  }
}