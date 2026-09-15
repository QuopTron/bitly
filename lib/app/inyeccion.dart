// inyeccion.dart — Registro central de dependencias (GetIt): valores
// core, base de datos, caches, backend Go, servicios y cubits/blocs.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../core/backend_go/plataformas/backend_android.dart';
import '../core/backend_go/plataformas/backend_escritorio.dart';
import '../core/backend_go/plataformas/backend_ios.dart';
import '../core/backend_go/plataformas/backend_web.dart';
import '../core/backend_go/nucleo/contrato_backend.dart';
import '../core/base_datos/app_database.dart';
import '../core/cache/almacenes/cache_ajustes.dart';
import '../core/cache/almacenes/cache_premium.dart';
import '../core/cache/almacenes/cache_descargas.dart';
import '../core/cache/almacenes/cache_favoritos.dart';
import '../core/cache/almacenes/cache_detalle.dart';
import '../core/cache/almacenes/cache_detalle_memoria.dart';
import '../core/cache/almacenes/cache_busqueda.dart';
import '../core/cache/almacenes/cache_biblioteca.dart';
import '../core/cache/almacenes/cache_colecciones.dart';
import '../core/cache/almacenes/cache_feed.dart';
import '../core/cache/reproduccion/reproduccion_cache.dart';
import '../core/cache/reproduccion/reproduccion_stats.dart';
import '../core/cache/reproduccion/reproduccion_detalle_local.dart';
import '../core/cache/reproduccion/reproduccion_sync.dart';
import '../core/modelos/usuario/estilo_visual.dart';
import '../core/modelos/usuario/perfil_rendimiento.dart';
import '../core/modelos/usuario/preferencias_estilo.dart';
import '../core/servicios/playlist/servicio_dominio_playlist.dart';
import '../features/setup/bloc/setup_bloc.dart';
import '../features/splash/bloc/splash_bloc.dart';
import '../estado/cola/cubit_cola.dart';
import '../estado/descargas/cubit_descargas.dart';
import '../estado/like/cubit_like.dart';
import '../estado/playlists/cubit_playlists.dart';
import '../estado/reproductor/cubit_reproductor.dart';

part 'inyeccion_estado.dart';

final sl = GetIt.instance;

Future<void> configurarDependencias() async {
  // ── 1. Valores core ───────────────────────────────────────
  sl.registerLazySingleton<ValueNotifier<Locale>>(
    () => ValueNotifier(const Locale('es')),
  );
  sl.registerLazySingleton<ValueNotifier<ThemeMode>>(
    () => ValueNotifier(ThemeMode.dark),
  );
  sl.registerLazySingleton<ValueNotifier<EstiloVisual>>(
    () => ValueNotifier(EstiloVisual.clasico),
  );
  sl.registerLazySingleton<ValueNotifier<PreferenciasEstilo>>(
    () => ValueNotifier(const PreferenciasEstilo()),
  );
  sl.registerLazySingleton<ValueNotifier<PerfilRendimiento>>(
    () => ValueNotifier(PerfilRendimiento.medio),
  );

  // ── 2. Base de datos ──────────────────────────────────────
  final db = await AppDatabase.create();
  await db.migrateLegacyCoverPaths();
  sl.registerLazySingleton<AppDatabase>(() => db);

  // ── 3. Caches (dependen de AppDatabase) ───────────────────
  sl.registerLazySingleton<CacheAjustes>(() => CacheAjustes(db));
  sl.registerLazySingleton<CachePremium>(() => CachePremium(db));
  sl.registerLazySingleton<CacheDescargas>(() => CacheDescargas(db));
  sl.registerLazySingleton<CacheFavoritos>(() => CacheFavoritos(db));
  sl.registerLazySingleton<CacheDetalle>(() => CacheDetalle(db));
  sl.registerLazySingleton<CacheDetalleMemoria>(() => CacheDetalleMemoria());
  sl.registerLazySingleton<CacheBusqueda>(() => CacheBusqueda(db));
  sl.registerLazySingleton<CacheBiblioteca>(() => CacheBiblioteca(db));
  sl.registerLazySingleton<CacheColecciones>(() => CacheColecciones(db));
  sl.registerLazySingleton<CacheFeed>(() => CacheFeed(db));
  sl.registerLazySingleton<ReproduccionCache>(() => ReproduccionCache(db));
  sl.registerLazySingleton<ReproduccionStats>(() => ReproduccionStats(db));
  sl.registerLazySingleton<ReproduccionDetalleLocal>(() => ReproduccionDetalleLocal(db));
  sl.registerLazySingleton<ReproduccionSync>(() => ReproduccionSync(db));

  // ── 4. Backend (plataforma) ───────────────────────────────
  // En web NUNCA se toca `Platform` (dart:io no está en el navegador):
  // el backend web habla por HTTP con el servidor Go, que el usuario
  // arranca con `bitly-backend --web`.
  BackendService backend;
  if (kIsWeb) {
    backend = BackendWeb();
  } else if (Platform.isAndroid) {
    backend = BackendAndroid();
  } else if (Platform.isIOS) {
    backend = BackendIOS();
  } else {
    final sep = Platform.pathSeparator;
    String? rutaExe;
    if (Platform.isWindows) {
      rutaExe = '${Platform.resolvedExecutable}$sep..${sep}bitly-backend.exe';
    } else if (Platform.isMacOS) {
      // macOS usa el MISMO patrón que Windows/Linux: el backend Go va como
      // binario al lado del runner (Runner.app/Contents/MacOS/bitly-backend)
      // y habla JSON-RPC por 127.0.0.1:55009. El workflow de release lo copia
      // dentro del .app antes de armar el DMG.
      rutaExe = '${Platform.resolvedExecutable}$sep..${sep}bitly-backend';
    } else if (Platform.isLinux) {
      rutaExe = '${Platform.resolvedExecutable}$sep..${sep}bitly-backend';
    }
    backend = BackendEscritorio(
      rutaEjecutable: rutaExe,
      baseUrl: 'http://127.0.0.1:55009/rpc',
    );
  }
  sl.registerLazySingleton<BackendService>(() => backend);

  // Servicios de dominio, cubits/blocs globales y navegación.
  registrarServiciosYEstado(backend);
}

/// Carga el perfil de rendimiento guardado al notificador global.
/// IMPORTANTE: solo llamar DESPUÉS de que el backend Go esté inicializado
/// (healthCheck) — el push del perfil es un RPC y antes del init puede
/// bloquear el bridge nativo y colgar el splash.
Future<void> cargarPerfilRendimiento() async {
  final cache = sl<CacheAjustes>();
  final nivel = await cache.getNivelRendimiento();
  final perfil = PerfilRendimiento.paraNivel(nivel);
  sl<ValueNotifier<PerfilRendimiento>>().value = perfil;
}

/// Empuja el perfil de rendimiento cargado al backend Go. Llamar después
/// del healthCheck (runtime Go arriba) para que el RPC devuelva al instante
/// en vez de encolarse detrás del init nativo.
Future<void> empujarPerfilRendimientoABackend() async {
  final perfil = sl<ValueNotifier<PerfilRendimiento>>().value;
  try {
    (sl<BackendService>()).syncBackendConfig(
      mode: perfil.nivel.clave,
      streamCacheMaxMb: perfil.cacheStreamingMaxMb,
      downloadConcurrency: perfil.concurrenciaDescargas,
      streamChunkSize: perfil.tamanoChunkStreaming,
    );
  } catch (e) { debugPrint("[App] $e"); }
}