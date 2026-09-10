// ─────────────────────────────────────────────────────────────
// backend_android.dart — Implementación del backend Go para Android
// vía MethodChannel ('com.bitly/backend'). El arranque copia las
// extensiones de assets y sincroniza config/premium/perfil a Go.
// Se conecta con: backend_go (mixins RPC) + app/inyeccion (caches).
// Parte del flujo: arranque (healthCheck → initGoBackend).
// ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../config/secretos.dart';
import '../cache/cache_premium.dart';
import '../cache/cache_ajustes.dart';
import '../servicios/servicio_credenciales_proveedor.dart';
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

class BackendAndroid extends BackendService
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

  static const _archivosExt = <String, List<String>>{
    'amazon': ['index.js', 'manifest.json'],
    'apple-music': ['index.js', 'manifest.json'],
    'deezer': ['index.js', 'manifest.json'],
    'pandora': ['index.js', 'manifest.json'],
    'qobuz-web': ['index.js', 'manifest.json'],
    'soundcloud': ['index.js', 'manifest.json'],
    'spotify-web': ['index.js', 'manifest.json'],
    'tidal-web': ['index.js', 'manifest.json'],
    'ytmusic-spotiflac': ['icon.jpg', 'index.js', 'manifest.json'],
  };

  Future<void> _garantizarExtensiones(String dirExt) async {
    try {
      for (final entrada in _archivosExt.entries) {
        for (final archivo in entrada.value) {
          try {
            final data = await rootBundle.load('assets/extensions/${entrada.key}/$archivo');
            final destino = File('$dirExt/${entrada.key}/$archivo');
            destino.parent.createSync(recursive: true);
            await destino.writeAsBytes(data.buffer.asUint8List());
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

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
        } catch (_) {}

        // Sincroniza la config guardada a la config en memoria de Go.
        try {
          final rutaDesc = await di.sl<CacheAjustes>().getRutaDescargas();
          if (rutaDesc != null && rutaDesc.isNotEmpty) await syncDownloadDir(rutaDesc);
          final datosSetup = await di.sl<CacheAjustes>().cargarDatosSetup();
          if (datosSetup != null) {
            await syncBackendConfig(mode: datosSetup.mode);
          }
          // Sincroniza el estado premium (drift) a Go para que el gate de
          // descargas respete códigos ya activados en una sesión previa.
          final premium = await di.sl<CachePremium>().getEstadoPremium();
          await syncPremiumStatus(
            isPremium: premium.esPremium,
            tier: premium.tier,
            expiresAt: premium.premiumHasta,
          );
          // Empuja el perfil de rendimiento (concurrencia/buffer) ahora que
          // el runtime Go está confirmado — antes podría bloquear el bridge.
          await di.empujarPerfilRendimientoABackend();
          // Sincroniza la prioridad de proveedores de descarga persistida.
          final prioridad = await di.sl<CacheAjustes>().getPrioridadProveedoresDescarga();
          if (prioridad.isNotEmpty) await syncDownloadProviderPriority(prioridad);
        } catch (_) {}

        // Empuja las credenciales guardadas de proveedores a las extensiones.
        try {
          final cache = di.sl<CacheAjustes>();
          await ServicioCredencialesProveedor(this, cache).empujarCredencialesAlArrancar();
        } catch (_) {}

        _inicializado = true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}