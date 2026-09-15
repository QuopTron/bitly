// ─────────────────────────────────────────────────────────────
// backend_android.dart — Implementación del backend Go para Android
// vía MethodChannel ('com.bitly/backend'). El arranque copia las
// extensiones de assets y sincroniza config/premium/perfil a Go.
// Se conecta con: backend_go (mixins RPC) + app/inyeccion (caches).
// Parte del flujo: arranque (healthCheck → initGoBackend).
// ─────────────────────────────────────────────────────────────

import "package:flutter/foundation.dart";
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../config/secretos.dart';
import '../../cache/almacenes/cache_premium.dart';
import '../../cache/almacenes/cache_ajustes.dart';
import '../../servicios/proveedores/servicio_credenciales_proveedor.dart';
import '../../../app/inyeccion.dart' as di;
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
part 'backend_android_arranque.dart';

class BackendAndroid extends BackendService
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
  static const _canal = MethodChannel('com.bitly/backend');
  bool _inicializado = false;

  @override
  Future<dynamic> rpcCall(String method, [Map<String, dynamic>? params, Duration? timeout]) async {
    // Timeout defensivo para que un RPC colgado de Go nunca congele la UI.
    // Los llamadores legítimamente largos (stream de FLAC completo) pasan
    // un timeout mayor explícitamente.
    return _canal.invokeMethod(method, params ?? {}).timeout(
      timeout ?? const Duration(seconds: 60),
    );
  }

  @override
  Future<bool> healthCheck() async {
    try {
      if (!_inicializado) {
        final dir = await getApplicationDocumentsDirectory();
        final rutaYtDlp = '${dir.path}/yt-dlp';
        // Timeouts en cada llamada de init para que un arranque en frío
        // lento (runtime Go + motores JS de extensiones) nunca cuelgue el
        // splash — y para que el auto-reintento del splash avance si el
        // primer intento falla. El lado nativo espera hasta 120s por el init
        // real de Go, así que el timeout Dart debe ser al menos eso.
        await _canal
            .invokeMethod('initGoBackend', {'app_data_dir': dir.path, 'ytdlp_path': rutaYtDlp})
            .timeout(const Duration(seconds: 125));
        await setPremiumGithubToken(tokenGithub);
        final dirExt = '${dir.path}/extensions';
        await _garantizarExtensiones(dirExt);
        await _canal
            .invokeMethod('initExtensionSystem', {'extensions_dir': dirExt, 'data_dir': '${dir.path}/ext_data'})
            .timeout(const Duration(seconds: 30));
        try {
          await _canal
              .invokeMethod('loadExtensionsFromDir', {'dir_path': dirExt})
              .timeout(const Duration(seconds: 30));
        } catch (e) { debugPrint("[Backend] $e"); }

        await _sincronizarArranqueGo(this);
        _inicializado = true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}