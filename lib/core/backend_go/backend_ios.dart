// ─────────────────────────────────────────────────────────────
// backend_ios.dart — Implementación del backend Go para iOS vía
// MethodChannel ('com.bitly/backend'). El arranque inicializa Go y
// sincroniza config/premium/perfil.
// Se conecta con: backend_go (mixins RPC) + app/inyeccion (caches).
// Parte del flujo: arranque (healthCheck → initGoBackend).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/services.dart';

import '../../config/secretos.dart';
import '../cache/cache_premium.dart';
import '../cache/cache_ajustes.dart';
import '../../app/inyeccion.dart' as di;
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

class BackendIOS extends BackendService
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
  static const _canal = MethodChannel('com.bitly/backend');
  bool _inicializado = false;

  @override
  Future<dynamic> rpcCall(String method, [Map<String, dynamic>? params, Duration? timeout]) async {
    return _canal.invokeMethod(method, params ?? {}).timeout(
      timeout ?? const Duration(seconds: 60),
    );
  }

  @override
  Future<bool> healthCheck() async {
    try {
      if (!_inicializado) {
        final dir = await _canal.invokeMethod('getApplicationDocumentsDirectory');
        await _canal.invokeMethod('initGoBackend', {'app_data_dir': dir});
        await setPremiumGithubToken(tokenGithub);
        await _canal.invokeMethod('loadExtensionsFromDir', {'dir_path': '$dir/extensions'});

        // Sincroniza la config guardada a la config en memoria de Go.
        try {
          final rutaDesc = await di.sl<CacheAjustes>().getRutaDescargas();
          if (rutaDesc != null && rutaDesc.isNotEmpty) await syncDownloadDir(rutaDesc);
          final datosSetup = await di.sl<CacheAjustes>().cargarDatosSetup();
          if (datosSetup != null) {
            await syncBackendConfig(mode: datosSetup.mode);
          }
          // Sincroniza el estado premium (drift) a Go.
          final premium = await di.sl<CachePremium>().getEstadoPremium();
          await syncPremiumStatus(
            isPremium: premium.esPremium,
            tier: premium.tier,
            expiresAt: premium.premiumHasta,
          );
          // Empuja el perfil de rendimiento ahora que Go está arriba (antes
          // podría bloquear el bridge y colgar el splash).
          await di.empujarPerfilRendimientoABackend();
        } catch (_) {}

        _inicializado = true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}