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
  // Traducción de la letra del karaoke: singleton (su caché en memoria se
  // comparte entre aperturas del modal) y con respaldo en la base, así que la
  // canción ya traducida no se vuelve a pedir ni tras cerrar la app.
  sl.registerLazySingleton<ServicioTraduccionLetras>(
    () => ServicioTraduccionLetras(cache: sl<AlmacenTraducciones>()),
  );
  sl.registerLazySingleton<ServicioDominioPlaylist>(
    () => ServicioDominioPlaylist(backend),
  );
  // Guarda las playlists creadas/editadas a mano (nombre, portada y las
  // canciones exactas, en orden) dejando la biblioteca local al día.
  sl.registerLazySingleton<ServicioEditorPlaylist>(
    () => ServicioEditorPlaylist(
      sl<AppDatabase>(),
      sl<CacheColecciones>(),
      sl<CacheDetalleMemoria>(),
    ),
  );

  // Canciones likeadas/descargadas para armar playlists, leídas de la
  // base (no del estado en memoria, que se carga async al arrancar).
  sl.registerLazySingleton<FuentesPlaylist>(
    () => FuentesPlaylist(sl<CacheFavoritos>(), sl<CacheDescargas>()),
  );

  // Aparatos de la cuenta (burbuja Conexión): guarda la lista, quién manda y
  // la prueba de 9 horas. El plan se consulta a la base en cada apertura de
  // Ajustes, así un Premium recién activado ya cuenta como tal sin reiniciar.
  sl.registerLazySingleton<ServicioConexion>(
    () => ServicioConexion(
      sl<CacheAjustes>(),
      esPremium: () async {
        final estado = await sl<CachePremium>().getEstadoPremium();
        return estado.esPremium;
      },
    ),
  );

  // El vínculo entre aparatos de la MISMA red: cada app anuncia quién es y
  // presta su biblioteca descargada, sin servidor de nadie. Se arranca al
  // abrir la app (main), no acá, para no abrir puertos durante los tests.
  sl.registerLazySingleton<ServicioLan>(
    () => ServicioLan(
      cache: sl<CacheAjustes>(),
      descargas: sl<CacheDescargas>(),
      db: sl<AppDatabase>(),
      identidad: () async {
        final conexion = sl<ServicioConexion>();
        if (!conexion.cargado) await conexion.cargar();
        return (conexion.idPropio, conexion.esteDispositivo?.nombre ?? '');
      },
    ),
  );
  // Al aceptar un vínculo en la red, el aparato queda vinculado también en la
  // lista de Conexión (es el mismo aparato, con el id de Conexión).
  sl<ServicioLan>().alVincular = (id, nombre) {
    unawaited(sl<ServicioConexion>().vincular(id, nombre));
  };

  // El MODO FIESTA: varios aparatos sonando a la vez como un solo parlante
  // grande. El host publica lo que suena y sirve ese audio por la red local;
  // el invitado lo sigue con su propio motor (el de la app queda en pausa).
  // Necesita la foto del reproductor, así que se registra después de los
  // cubits de música (abajo) y se crea la primera vez que se usa.
  sl.registerLazySingleton<ServicioFiesta>(
    () => ServicioFiesta(
      instantanea: () => sl<CubitReproductor>().instantaneaFiesta,
      pausarLocal: () => sl<CubitReproductor>().pausar(),
      identidad: () async {
        final conexion = sl<ServicioConexion>();
        if (!conexion.cargado) await conexion.cargar();
        return (conexion.idPropio, conexion.esteDispositivo?.nombre ?? '');
      },
    ),
  );
  // El mini-servidor le pasa al modo fiesta sus rutas (ya con token válido).
  sl<ServicioLan>().manejadorFiesta =
      (pedido) => sl<ServicioFiesta>().atenderPedido(pedido);

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
