// ─────────────────────────────────────────────────────────────
// inyeccion_estado.dart — PART de inyeccion.dart: registra en GetIt
// los servicios de dominio, los cubits globales, los blocs globales
// (splash + setup) y los notificadores de navegación. Se llama al
// final de configurarDependencias, cuando el backend ya está elegido.
// Se conecta con: inyeccion.dart (misma library) + backend + cubits
// + blocs + router.
// Parte del flujo: arranque (registro de dependencias).
// ─────────────────────────────────────────────────────────────

part of 'inyeccion.dart';

/// Registra servicios de dominio, cubits/blocs globales y navegación.
void registrarServiciosYEstado(BackendService backend) {
  // ── 5. Servicios de dominio ──────────────────────────────
  sl.registerLazySingleton<ServicioDominioPlaylist>(
    () => ServicioDominioPlaylist(backend),
  );

  // ── 6. Cubits globales ───────────────────────────────────
  // (player_cubit y los blocs de vistas se crean en el ensamblador
  //  de Home; el reproductor se registra al migrar features/reproductor)
  sl.registerLazySingleton<CubitCola>(() => CubitCola());
  sl.registerLazySingleton<CubitLikes>(
    () => CubitLikes(backend)..inicializar(),
  );
  sl.registerLazySingleton<CubitDescargas>(
    () => CubitDescargas(backend)..initialize(),
  );
  sl.registerLazySingleton<CubitPlaylists>(
    () => CubitPlaylists(sl<ServicioDominioPlaylist>())..inicializar(),
  );
  sl.registerLazySingleton<CubitReproductor>(
    () => CubitReproductor(sl<CubitCola>()),
  );

  // ── 7. Blocs globales (splash + setup) ───────────────────
  sl.registerLazySingleton<SplashBloc>(() => SplashBloc(backend));
  sl.registerLazySingleton<SetupBloc>(
    () => SetupBloc(sl<ValueNotifier<Locale>>()),
  );

  // ── 8. Navegación ─────────────────────────────────────────
  // Índice de la pestaña activa de la Home (0=búsqueda, 1=inicio,
  // 2=mi espacio). El navbar global lo escribe para volver a la Home
  // en la pestaña correcta; HomePage lo escucha para animar.
  sl.registerLazySingleton<ValueNotifier<int>>(() => ValueNotifier<int>(1));
}
