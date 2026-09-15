// ─────────────────────────────────────────────────────────────
// backend_escritorio_arranque.dart — PART de backend_escritorio.dart:
// rutinas de arranque del backend Go en escritorio (CWD escribible en
// macOS, carga del sistema de extensiones, alta del callback de
// sesiones firmadas y empuje de premium/credenciales).
// Se conecta con: backend_escritorio.dart (misma library).
// Parte del flujo: arranque (healthCheck → init post-ping).
// ─────────────────────────────────────────────────────────────

part of 'backend_escritorio.dart';

/// Devuelve un directorio de trabajo escribible para el proceso Go.
///
/// En macOS una app GUI lanzada por Finder/Dock hereda "/" como CWD (solo
/// lectura) y el gestor de bins (yt-dlp) + los stores de extensiones
/// fallarían al crear carpetas ahí. Apuntamos al directorio de datos de la
/// app (mismo rol que app_data_dir en Android). En Windows/Linux el exe ya
/// vive en una carpeta escribible y se devuelve null.
Future<String?> _cwdEscribible() async {
  if (!Platform.isMacOS) return null;
  try {
    final home = Platform.environment['HOME'] ?? '';
    final dirDatos = '$home/Library/Application Support/com.example.bitly';
    await Directory(dirDatos).create(recursive: true);
    return dirDatos;
  } catch (e) {
    debugPrint("[Backend] $e");
    return null;
  }
}

/// Busca el directorio de extensiones: junto al exe, luego CWD/assets,
/// luego CWD/extensions. Devuelve null si no encuentra ninguno.
Future<String?> _buscarDirExtensiones(String? rutaEjecutable) async {
  final padreExe = rutaEjecutable != null ? File(rutaEjecutable).parent.path : null;
  if (padreExe != null && await Directory('$padreExe/extensions').exists()) {
    return '$padreExe/extensions';
  }
  if (await Directory('${Directory.current.path}/assets/extensions').exists()) {
    return '${Directory.current.path}/assets/extensions';
  }
  if (await Directory('${Directory.current.path}/extensions').exists()) {
    return '${Directory.current.path}/extensions';
  }
  return null;
}

/// Inicializa el sistema de extensiones del backend Go (no fatal).
Future<void> _initExtensiones(BackendEscritorio backend, String dirExt) async {
  try {
    var dirDatos = '$dirExt/../ext_data';
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      dirDatos = '$home/Library/Application Support/com.example.bitly/ext_data';
      await Directory(dirDatos).create(recursive: true);
    }
    await backend.rpcCall('initExtensionSystem', {
      'extensions_dir': dirExt,
      'data_dir': dirDatos,
    });
    await backend.rpcCall('loadExtensionsFromDir', {'dir_path': dirExt});
  } catch (e) {
    debugPrint('[backend] init de extensiones falló (no fatal): $e');
  }
}

/// Registra el callback local de sesiones firmadas (no aplica en macOS).
Future<void> _initCallback(BackendEscritorio backend) async {
  try {
    if (await ServidorCallbackEscritorio.instance.garantizarIniciado()) {
      final puerto = ServidorCallbackEscritorio.instance.puerto;
      if (puerto != null) {
        await backend.rpcCall('setSignedSessionCallbackUrl', {
          'url': 'http://127.0.0.1:$puerto/session-grant',
        });
      }
    }
  } catch (e) {
    debugPrint("[Backend] $e");
  }
}

/// Empuja al backend el estado premium y las credenciales de proveedores.
Future<void> _initPremiumCredenciales(BackendEscritorio backend) async {
  try {
    final premium = await sl<CachePremium>().getEstadoPremium();
    await backend.syncPremiumStatus(
      isPremium: premium.esPremium,
      tier: premium.tier,
      expiresAt: premium.premiumHasta,
    );
  } catch (e) {
    debugPrint("[Backend] $e");
  }

  try {
    final cache = sl<CacheAjustes>();
    await ServicioCredencialesProveedor(backend, cache)
        .empujarCredencialesAlArrancar();
  } catch (e) {
    debugPrint("[Backend] $e");
  }
}
