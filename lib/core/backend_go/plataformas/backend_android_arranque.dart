// ─────────────────────────────────────────────────────────────
// backend_android_arranque.dart — PART de backend_android.dart:
// rutinas de arranque del backend Go en Android — qué archivos de
// cada extensión se copian desde assets y la sincronización a Go de
// la config guardada (ruta de descargas, modo, premium, perfil de
// rendimiento, prioridad de proveedores) y de las credenciales.
// Se conecta con: backend_android.dart (misma library) + caches.
// Parte del flujo: arranque (initGoBackend → sync de config).
// ─────────────────────────────────────────────────────────────

part of 'backend_android.dart';

/// Archivos que se copian de assets por cada extensión embebida.
const _archivosExt = <String, List<String>>{
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

/// Copia a [dirExt] los assets de todas las extensiones embebidas.
Future<void> _garantizarExtensiones(String dirExt) async {
  try {
    for (final entrada in _archivosExt.entries) {
      for (final archivo in entrada.value) {
        try {
          final data = await rootBundle
              .load('assets/extensions/${entrada.key}/$archivo');
          final destino = File('$dirExt/${entrada.key}/$archivo');
          destino.parent.createSync(recursive: true);
          await destino.writeAsBytes(data.buffer.asUint8List());
        } catch (e) {
          debugPrint("[Backend] $e");
        }
      }
    }
  } catch (e) {
    debugPrint("[Backend] $e");
  }
}

/// Sincroniza a la config en memoria de Go todo lo guardado en la app:
/// ruta de descargas, modo, premium, perfil de rendimiento, prioridad de
/// proveedores y las credenciales de proveedores.
Future<void> _sincronizarArranqueGo(BackendAndroid backend) async {
  try {
    final rutaDesc = await di.sl<CacheAjustes>().getRutaDescargas();
    if (rutaDesc != null && rutaDesc.isNotEmpty) {
      await backend.syncDownloadDir(rutaDesc);
    }
    final datosSetup = await di.sl<CacheAjustes>().cargarDatosSetup();
    if (datosSetup != null) {
      await backend.syncBackendConfig(mode: datosSetup.mode);
    }
    // Sincroniza el estado premium (drift) a Go para que el gate de
    // descargas respete códigos ya activados en una sesión previa.
    final premium = await di.sl<CachePremium>().getEstadoPremium();
    await backend.syncPremiumStatus(
      isPremium: premium.esPremium,
      tier: premium.tier,
      expiresAt: premium.premiumHasta,
    );
    // Empuja el perfil de rendimiento (concurrencia/buffer) ahora que
    // el runtime Go está confirmado — antes podría bloquear el bridge.
    await di.empujarPerfilRendimientoABackend();
    // Sincroniza la prioridad de proveedores de descarga persistida.
    final prioridad =
        await di.sl<CacheAjustes>().getPrioridadProveedoresDescarga();
    if (prioridad.isNotEmpty) {
      await backend.syncDownloadProviderPriority(prioridad);
    }
  } catch (e) {
    debugPrint("[Backend] $e");
  }

  // Empuja las credenciales guardadas de proveedores a las extensiones.
  try {
    final cache = di.sl<CacheAjustes>();
    await ServicioCredencialesProveedor(backend, cache)
        .empujarCredencialesAlArrancar();
  } catch (e) {
    debugPrint("[Backend] $e");
  }
}
