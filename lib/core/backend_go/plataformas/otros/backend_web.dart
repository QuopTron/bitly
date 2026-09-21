// ─────────────────────────────────────────────────────────────
// backend_web.dart — Implementación del backend Go para el
// navegador (PWA). Habla el MISMO JSON-RPC 2.0 que la versión de
// escritorio, pero por HTTP contra el servidor web del backend:
//
//     bitly-backend --web      (o WEB_MODE=1)
//
// Ese modo sirve los archivos de Flutter web Y la API en el mismo
// puerto (8080 por defecto, en 0.0.0.0), así que el navegador le
// habla al MISMO origen: no hay CORS que negociar ni puerto que
// adivinar. El servidor ya trae los headers CORS por si la web se
// sirve desde otro host.
//
// Diferencias con escritorio (porque el navegador no puede):
//   · NO lanza un proceso (no hay Process en web): el binario Go lo
//     arranca el usuario.
//   · NO escanea directorios de extensiones: el servidor en modo web
//     carga las extensiones empaquetadas por su cuenta.
//   · NO abre el servidor de callback loopback (sin sockets en web).
//
// Se conecta con: contrato_backend (mixins RPC) + app/inyeccion.
// Parte del flujo: arranque en web (healthCheck → ping al servidor).
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../config/secretos.dart';
import '../../../../app/inyeccion/inyeccion.dart' as di;
import '../../../cache/almacenes/sistema/cache_premium.dart';
import '../../nucleo/base/contrato_backend.dart';
import '../../mixins/base/acciones_mixin.dart';
import '../../mixins/base/ajustes_mixin.dart';
import '../../mixins/biblioteca/biblioteca_local_mixin.dart';
import '../../mixins/musica/detalle_mixin.dart';
import '../../mixins/biblioteca/editor_etiquetas_mixin.dart';
import '../../mixins/biblioteca/isrc_mixin.dart';
import '../../mixins/musica/enlaces_mixin.dart';
import '../../mixins/musica/feed_busqueda_mixin.dart';
import '../../mixins/base/infra_mixin.dart';
import '../../mixins/base/premium_mixin.dart';
import '../../mixins/sesiones/sesiones_acciones_mixin.dart';
import '../../mixins/sesiones/sesiones_firmadas_mixin.dart';
import '../../mixins/sesiones/sesiones_keepalive_mixin.dart';
import '../../nucleo/base/rpc_backend_mixin.dart';

class BackendWeb extends BackendService
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
        IsrcMixin,
        SesionesFirmadasMixin,
        SesionesAccionesMixin,
        SesionesKeepaliveMixin,
        RpcBackendMixin {
  /// Endpoint JSON-RPC. Por defecto el MISMO origen que sirvió la web
  /// (que es donde el backend Go en modo web expone /rpc).
  final Uri baseUrl;
  final http.Client _cliente;
  bool _iniciado = false;
  int _contadorId = 1;

  BackendWeb({Uri? baseUrl, http.Client? cliente})
    : baseUrl = baseUrl ?? _endpointPorDefecto(),
      _cliente = cliente ?? http.Client();

  /// Resuelve el endpoint. Permite apuntar a otro host con
  /// `?backend=http://127.0.0.1:8080/rpc` (útil si la web se sirve
  /// desde un hosting estático y el backend corre aparte).
  static Uri _endpointPorDefecto() {
    final override = Uri.base.queryParameters['backend'];
    if (override != null && override.trim().isNotEmpty) {
      return Uri.parse(override.trim());
    }
    return Uri.base.resolve('rpc');
  }

  Future<void> _garantizarEnMarcha() async {
    if (_iniciado) return;
    _iniciado = true;
    // En web no se puede lanzar el proceso: solo se avisa si no responde.
    try {
      if (await rpcCall('ping') != 'pong') {
        debugPrint('[backend-web] el servidor no respondió al ping');
      }
    } catch (e) {
      debugPrint('[backend-web] sin backend en $baseUrl: $e');
    }
  }

  @override
  Future<dynamic> rpcCall(
    String method, [
    Map<String, dynamic>? params,
    Duration? timeout,
  ]) async {
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'id': _contadorId++,
      'method': method,
      'params': params ?? {},
    });
    final res = await _cliente
        .post(
          baseUrl,
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(timeout ?? const Duration(seconds: 60));
    final decodificado = jsonDecode(res.body);
    if (decodificado is! Map) throw Exception('Respuesta RPC inesperada');
    if (decodificado['error'] != null) {
      throw Exception(decodificado['error'] ?? 'Error RPC');
    }
    return decodificado['result'];
  }

  @override
  Future<bool> healthCheck() async {
    try {
      await _garantizarEnMarcha();
      if (await rpcCall('ping') != 'pong') return false;

      await setPremiumGithubToken(tokenGithub);

      // Estado premium local (drift del navegador) → Go, para que el gate de
      // descargas respete códigos activados en una sesión previa.
      try {
        final premium = await di.sl<CachePremium>().getEstadoPremium();
        await syncPremiumStatus(
          isPremium: premium.esPremium,
          tier: premium.tier,
          expiresAt: premium.premiumHasta,
        );
      } catch (e) {
        debugPrint("[Backend] $e");
      }

      // Perfil de rendimiento (concurrencia/buffer) ahora que el servidor
      // respondió.
      try {
        await di.empujarPerfilRendimientoABackend();
      } catch (e) {
        debugPrint("[Backend] $e");
      }

      return true;
    } catch (e) {
      debugPrint('[BackendWeb] $e');
      return false;
    }
  }

  void dispose() {
    _cliente.close();
  }
}
