# lib-nuevo — Arquitectura Bitly (Flutter + Go)

> **Misión:** reconstruir `lib/` completo dentro de esta carpeta con la mejor
> arquitectura Flutter (patrón **Bloc**), en español, archivos de **100–150
> líneas máximo**, y con un comentario arriba de cada archivo explicando:
> **qué hace, con qué se conecta y qué parte del flujo es**.
>
> Esta carpeta es la **nueva versión** — el diseño actual es para **celular**;
> luego se replica para PC/tablet (el diseño móvil se deja intacto).

---

## 1. Flujo general de la app

```
main.dart (arranque)
   │
   ├─ 1. media_kit + servicios de plataforma (audio focus, notificación, deep links)
   ├─ 2. configureDependencies() → inyección de dependencias (GetIt)
   └─ 3. runApp(BitlyApp)
          │
          ├─ SplashBloc → healthCheck() contra Go (arranca el backend nativo)
          ├─ SetupBloc → configuración inicial del usuario (fuentes, modo)
          └─ HomePage → pestañas: Búsqueda · Inicio (feed) · Mi Espacio
                 │
                 ├─ FeedCubit/SearchBloc → piden datos al backend Go (RPC)
                 ├─ PlayerCubit/QueueCubit → reproducción local-first
                 ├─ DownloadCubit → descargas gestionadas por Go
                 └─ LikeCubit/PlaylistCubit → acciones en librería (drift)
```

**Backend Go** = el cerebro (fuentes de música, extensiones, descargas,
streaming, premium). Flutter es el cliente: le habla por **RPC**
(`backend_go/`), y guarda estado local en **drift** (`base_datos/`) + caches.

---

## 2. Estructura de carpetas

| Carpeta | Qué contiene |
|---|---|
| `app/` | Widget raíz `BitlyApp`, enrutador, inyección de dependencias |
| `config/` | Secretos y configuración global de la app |
| `core/modelos/` | Modelos de dominio puros (FeedItem, Detail, Provider...) |
| `core/backend_go/` | **TODO lo que conecta con Go**: contrato RPC, mixins, implementaciones Android/iOS/Desktop |
| `core/base_datos/` | Drift: tablas, DAOs y la base de datos |
| `core/cache/` | Caches locales (ajustes, premium, descargas, favoritos...) |
| `core/plataforma/` | Servicios nativos del SO (notificación, audio focus, deep links) |
| `core/servicios/` | Servicios de dominio que orquestan backend + caches (verificación Cloudflare, desencriptado ffmpeg, credenciales) |
| `estado/` | **Cubits/Blocs globales**: player, cola, descargas, likes, playlists |
| `features/<feature>/` | Una carpeta por funcionalidad: `bloc/`, `vista/`, `widgets/` |
| `shared/` | Widgets, tema y utilidades reutilizables (dialogos de verificación, tarjetas, modales) |
| `l10n/` | Traducciones (es/en) |

---

## 3. Patrón de una feature (Bloc)

```
features/busqueda/
├── bloc/
│   ├── busqueda_bloc.dart           # Bloc (eventos → estado) + parts:
│   │   ├── busqueda_cache.dart      #   cache LRU en memoria
│   │   ├── busqueda_intento.dart    #   streaming de la búsqueda
│   │   └── busqueda_verificacion.dart # finalización + sesión firmada
│   ├── busqueda_estado.dart         # Estado del bloc
│   └── busqueda_evento.dart         # Eventos del bloc
├── pagina_busqueda.dart             # Página: lógica compartida + selector variante
│   ├── pagina_busqueda_flujo.dart   #   part: persistencia + handlers + debounce
│   ├── pagina_busqueda_helpers.dart #   part: fuentes/filtros/hint + acciones
│   └── pagina_busqueda_widgets.dart #   part: barra/chips/cuerpo armados
├── busqueda_movil.dart              # Variante CELULAR (diseño actual)
├── busqueda_escritorio.dart         # Variante ESCRITORIO (panel centrado)
└── widgets/
    ├── barra_busqueda.dart          # Campo con vidrio + selector de fuente
    ├── chips_tipo_busqueda.dart     # Burbujas de categoría del manifest
    ├── busqueda_cuerpo.dart         # BlocSelectors like/descargas + decide vista
    ├── busqueda_recientes.dart      # Historial de búsquedas
    ├── busqueda_pegar_url.dart      # Vista inicial (pegar link)
    └── resultados_busqueda.dart     # Cuerpo de resultados + 5 parts
```

**Reglas del patrón:**
- La **vista** NUNCA hace lógica: solo escucha `BlocBuilder`/`BlocSelector` y emite eventos.
- El **bloc/cubit** contiene la lógica y habla con `core/` (backend Go + caches).
- Cada widget se separa en su propio archivo si supera ~100 líneas.
- Los widgets de UI pura (sin estado) se escriben como `StatelessWidget`.

---

## 4. Convenciones obligatorias

1. **Idioma:** código, variables, mensajes y comentarios en **español**.
2. **Tamaño:** 0–100 líneas por archivo (se acepta hasta 150).
3. **Encabezado:** TODO archivo empieza con un comentario:
   ```dart
   // ─────────────────────────────────────────────────────────────
   // NOMBRE_ARCHIVO — qué hace (1 frase)
   // Se conecta con: (backend Go / drift / otro cubit / nada)
   // Parte del flujo: (arranque / búsqueda / reproducción / ...)
   // ─────────────────────────────────────────────────────────────
   ```
4. **Nombres:** `camelCase` en español para variables/funciones,
   `PascalCase` para clases, `snake_case` para constantes y columnas DB.
5. **Imports:** relativos (`../core/...`), agrupados y ordenados.
6. **Sin código muerto:** nada de imports o variables sin usar.

---

## 5. Capa Backend Go (lo más importante)

`core/backend_go/` es la ÚNICA capa que habla con Go:

```
backend_go/
├── contrato_backend.dart    # Interfaz BackendService (RPCs disponibles)
├── backend_android.dart     # Implementación Android (MethodChannel)
├── backend_ios.dart         # Implementación iOS (MethodChannel)
├── backend_escritorio.dart  # Implementación Desktop (HTTP localhost)
├── rpc_backend_mixin.dart   # Mixin base de RPC (timeout defensivo)
└── mixins/                  # Un mixin por grupo de RPCs:
    ├── ajustes_mixin.dart       # Ajustes/config del backend
    ├── feed_busqueda_mixin.dart # Feed + búsqueda
    ├── acciones_mixin.dart      # Likes, descargas, acciones
    ├── detalle_mixin.dart       # Detalles (álbum/playlist/artista)
    ├── infra_mixin.dart         # Cache de carátulas, stats
    ├── premium_mixin.dart       # Premium + sesiones firmadas
    ├── editor_etiquetas_mixin.dart # Leer/escribir tags de audio
    ├── sesiones_firmadas_mixin.dart # URL verificación + estado (Cloudflare)
    ├── sesiones_acciones_mixin.dart  # invokeExtensionAction + grant
    └── sesiones_keepalive_mixin.dart # provision + keepalive
```

**Regla:** las vistas y cubits NUNCA importan `backend_go` directamente;
siempre pasan por la interfaz `BackendService` (inyectada por GetIt), así se
puede mockear en tests y cambiar de plataforma sin tocar la UI.

---

## 6. Estado de migración

| Capa | Estado |
|---|---|
| `config/` | ✅ |
| `core/modelos/` | ✅ (14) |
| `core/backend_go/` | ✅ (14 + mixins) |
| `core/base_datos/` | ✅ (drift copiado, headers en español) |
| `core/cache/` | ✅ (dividido ≤150) |
| `core/plataforma/` | ✅ |
| `core/servicios/` | ✅ incluye desencriptado_stream (5 parts), servicio_verificacion (5 parts) |
| `estado/` | ✅ cola + likes + **reproductor (24 mixins ≤150)** + **descargas (3,141 líneas → 34 parts ≤150)** + playlists |
| `features/*` | ✅ splash + setup + busqueda + feed + miespacio + **detalle (álbum/playlist/artista + navegador real)** + **reproductor completo (NowPlaying + letras karaoke + cola)** + tutorial (doble variante) |
| `shared/` | ⬜ ✅ base + tarjetas (track/grilla) + esqueletos + acordeón fuente + indicador descarga + **modales (info/agregar a/opciones descarga)** + acciones_item · falta el resto |
| `app/` + `main.dart` | ⬜ |

> **Progreso: 196 archivos / ~18,800 líneas aprox (en esta tanda el cubit de
> descargas), `dart analyze` limpio** (todo ≤150 líneas salvo código generado
> por drift). Se avanza **archivo por archivo** desde `lib/` original,
> refactorizando, dividiendo a ≤150 líneas, y verificando con `dart analyze`
> al final de cada capa. Cuando todo esté migrado se hace el switch:
> `lib-nuevo` → `lib`.

### Reproducción (CubitReproductor)

El `PlayerCubit` original (2,535 líneas) se reparte en **24 mixins en cadena**
(cada uno `on` el anterior), todos ≤150 líneas y en `estado/reproductor_*.dart`:

```
base → estado_cache → stream → stream_proxy → stream_pipeline →
stream_resolve → archivos_temp → video_local → video_descarga →
video_fondo → preload → preload_media → controles → verificacion →
reporte → apertura_helpers → apertura → autoplay → limpieza →
completado → locales → player_setup → listener_cola → init
```

- `reproductor_base.dart` — campos del player (mpv, cola, subs, crossfade, volumen).
- `reproductor_estado_cache.dart` — caché de URLs/archivos, reintentos, generaciones anti-carrera y prefetch con throttle.
- `reproductor_stream*.dart` — resolución de URLs (helpers → proxy/headers/liveness → pipeline RPC+decrypt → resolve con caché/dedup).
- `reproductor_video_*.dart` — archivos locales (local-first) y video de fondo (visualizador InnerTube + descarga).
- `reproductor_preload*.dart` — precarga de vecinos (WiFi), siguiente inmediato (cualquier red) y letras/video del track actual.
- `reproductor_controles.dart` — play/pausa/seek/volumen/velocidad + fades del crossfade.
- `reproductor_verificacion.dart` / `reproductor_reporte.dart` — gate de sesión firmada (Cloudflare) y scrobbling.
- `reproductor_apertura*.dart` — apertura local-first con watchdog anti-stall y mensajes de error legibles.
- `reproductor_autoplay.dart` / `reproductor_limpieza.dart` — radio al agotar la cola y borrado de archivos/sidecars.
- `reproductor_completado.dart` — guards de EOF muerto/preview, play en drift, scrobble y avance con repetición.
- `reproductor_locales.dart` / `player_setup.dart` / `listener_cola.dart` / `init.dart` — carga de archivos locales, mpv (ao/audio-format para emuladores), sync cola↔player y cierre.

**Regla de los mixins en cadena:** los campos viven en los mixins de abajo
(base/estado_cache) y los métodos que una parte superior necesita de una
inferior se declaran abstract en la inferior (p.ej. `_resolveStreamUrl` en
`estado_cache`, `_openTrack` en `apertura_helpers`, `_loadLocalFiles` en
`video_local`). Los nombres públicos quedaron en español
(`reproducir`, `pausar`, `buscar`, `setVolumen`, `siguiente`...); `close()`
conserva su nombre porque es el hook de disposal del framework.

### Descargas (CubitDescargas)

El `DownloadCubit` original (3,141 líneas) se reparte en **34 parts encadenados**
(todos ≤150 líneas) en `estado/descargas_*.dart`. La cadena de mixins:

```
base → reparar → reparar_decrypt → reparar_escaneo → polling →
carga_tracks → carga_lotes → carga → cola_verificar → reintentar →
cola → estado → lote_finalizar → acceso → inicio → inicio_album →
inicio_playlist → borrar → borrar_playlist → borrar_lote → despacho →
track_borrar → track_batch → track → poll_fallido → poll_finalizar →
poll_persistir → poll_completado → poll_decrypt → poll_item →
poll_lotes → poll_timeout → poll_progreso
```

- `descargas_base.dart` + `descargas_modelos.dart` — campos de estado y clases auxiliares (_DatosLote, _TrackEnCola, _InfoTrack, _MetaLote).
- `descargas_reparar*.dart` — búsqueda de alternativas reproducibles, validación por magic bytes, decrypt DRM (ffmpeg-kit) y escaneo de arranque de descargas rotas.
- `descargas_carga*.dart` — restauración del historial (tracks con fingerprints nombre/ISRC y lotes con backfill de carátulas).
- `descargas_cola*.dart` / `descargas_reintentar.dart` — cola secuencial FIFO con consciencia de lote y reintentos de tracks fallidos.
- `descargas_estado.dart` — acks de UI, gate free, verificación Cloudflare (WebView por proveedor) y reintento de lotes interrumpidos.
- `descargas_inicio*.dart` — inicio de descarga single/álbum/playlist con dedup por ID e ISRC.
- `descargas_borrar*.dart` — borrado con respeto de referencias (otros lotes/likes conservan el archivo) y cancelación de trackers de Go.
- `descargas_poll_*.dart` — poll de 3s contra Go: por status de item, decrypt con fast paths, persistencia (carátula/BD/fingerprint/player), progreso de lotes y timeouts (racha vacía 18s y duro 120s).

**Aprendizajes de esta tanda:** los `part` no pueden tener imports (van al
principal); un miembro abstracto declarado en un mixin *inferior* es
implementado por uno *superior* (el lookup del `with` gana), pero si el
abstract va en el *superior* y la impl en el *inferior* se sombrea y crashea
en runtime (se arregló en `descargas_carga.dart`); los estáticos de un mixin
NO se heredan (se pasaron a campos de instancia); el `ñ` no es un carácter
válido en identificadores para este analyzer (`_señalizarTrackTerminado` →
`_senializarTrackTerminado`); los campos de mixin no se pueden inicializar en
el constructor de la clase (se asignan en el cuerpo, patrón del reproductor).

### Playlists (CubitPlaylists)

El `PlaylistCubit` original (188 líneas) + `playlist_generator_service.dart`
(247) + `playlist_export_service.dart` se reparten en 7 archivos (todos ≤150):

```
core/modelos/track_playlist.dart          — TrackPlaylist + ConfigPlaylist
core/servicios/generador_playlists.dart    — M3U/M3U8 (+ part CUE/NFO)
core/servicios/generador_playlists_cue_nfo.dart — CUE + NFO (part)
core/servicios/exportacion_playlist.dart   — ResultadoExportacionPlaylist + picker
shared/utilidades/exportacion_playlist_ui.dart — helper de UI para exportar
estado/playlists_estado.dart               — EstadoPlaylists + ItemPlaylist (part)
estado/cubit_playlists.dart                — CubitPlaylists (140 líneas)
```

- Métodos públicos en español: `inicializar`, `cargarPlaylists`, `cargarStats`,
  `crearPlaylist`, `agregarTrack`, `quitarTrack`, `cargarDetalle`,
  `actualizarCaratula`, `borrarPlaylist`, `limpiarDetalle`,
  `exportarPlaylistActual`, `exportarPlaylistPorId` (12/12 del original).
- `playlists_estado.dart` es `part of` el cubit (mismo patrón que descargas)
  para que la conversión privada `_dominioAItem` viva en el part.
- Los helpers `sanitizar`/`formatearDuracion` son estáticos de
  `GeneradorPlaylists` → el part CUE/NFO los llama con clase (`GeneradorPlaylists.sanitizar(...)`).

**Aprendizaje de esta tanda:** un `part` no puede usar un privado de otra
library → el estado que contiene conversiones privadas debe ser `part of`
el cubit (como `descargas_estado.dart`).

### Servicios de plataforma/backend restantes (OAuth + notificación)

Los últimos servicios de `lib/backend/services` se migraron a `lib-nuevo`:

```
core/servicios/oauth_youtube_app.dart          — OAuth YouTube in-app (WebView)
core/servicios/oauth_youtube_webview.dart      — página WebView del consentimiento
core/servicios/servicio_oauth_youtube.dart     — OAuth nativo + caída WebView (+ part nativo)
core/servicios/oauth_youtube_nativo.dart       — part: Google Sign-In nativo
core/servicios/resultado_oauth.dart            — ResultadoOAuth + parseo de callback URL
core/servicios/servicio_callback_oauth.dart    — espera callbacks PKCE por deep link
core/plataforma/puente_notificacion_media.dart — puente notificación media ↔ cubits (+ part comandos)
core/plataforma/manejador_notificacion_media.dart — AudioHandler del isolate de audio_service (+ part estado)
core/plataforma/notificacion_media_helpers.dart — mapeos de estado para la notificación
```

- **Decisión de arquitectura aplicada:** todo lo de plataforma/UI (notificación
  media, OAuth in-app, foco de audio, deep links, share intent, conectividad)
  se queda en Flutter; lo que es negocio/datos (streams, descargas, feed,
  scrobble, similar tracks, premium) ya vive en Go. No se movió nada a Go en
  esta tanda porque esos 10 métodos RPC ya existían en Go — solo faltaba
  migrar los mixins/llamadas de Flutter que los consumen.
- **Limpieza:** se eliminaron 8 archivos muertos de `lib/` (settings_sheet
  viejo duplicado de settings_sheet_new, 3 slides de tutorial sin importar,
  share_helper sin usar, y 3 stubs de play_services_check reemplazados por
  verificacion_play_services*). `dart analyze lib` sigue en 0 errores.
- **Aprendizaje de esta tanda:** en un `part`, los imports van SOLO en la
  library principal; los estáticos privados de una clase NO se ven desde
  funciones top-level del part (hay que pasarlos como top-level de la misma
  library o como parámetros); los miembros privados de instancia solo se
  acceden si la función del part recibe la instancia (`_conectarNativo(this)`
  y `_onMensajeControl(this, raw)`).

### REGLA DE VISTAS: separación PC / celular / TV (obligatoria de aquí en adelante)

Toda vista nueva debe separarse en **TRES variantes de layout** y un selector:

```
features/<feature>/pagina_<feature>.dart     → selector: elige según plataforma
features/<feature>/<feature>_movil.dart      → diseño CELULAR (el actual)
features/<feature>/<feature>_escritorio.dart → diseño PC/escritorio
features/<feature>/<feature>_tv.dart         → diseño TV (control remoto)
```

- **Celular (Android/iOS/tablet vertical):** el diseño actual — bottom navbar
  flotante, PageView, contenido full-width, modales/hojas.
- **Escritorio (Windows/Linux/macOS/web/pantallas anchas ≥900px):** diseño de
  escritorio — barra lateral fija de navegación, panel de contenido central
  con IndexedStack (secciones vivas), ancho máximo y layout horizontal.
- **TV (Android TV / Google TV / Fire TV):** navegación ARRIBA con ítems
  grandes (en una tele no hay hover que marque dónde estás), paneles PLANOS a
  todo el lienzo —nada de vidrio: el desenfoque se paga en cada frame y a
  metros no se ve, y en TV ya está apagado por perfil (ver inyeccion_perfil)—,
  y más aire y tipografía. El lienzo lógico fijo y el puntero del control los
  pone el arranque (`vista_tv` + `puntero_tv`). El molde de estas vistas es
  `shared/widgets/paneles/panel_tv.dart`.
- **Selectores ÚNICOS:** `usarLayoutTv(context)` PRIMERO y después
  `usarLayoutEscritorio(context)`, los dos de
  `shared/utilidades/deteccion_plataforma.dart` — ninguna vista duplica
  Platform.is* / MediaQuery.width checks. El orden importa: una tele ancha
  también entraría en el layout de escritorio.
- **Slots desacoplados:** los shells reciben las páginas internas como
  parámetros (`buscador`, `feed`, `miEspacio`, `miniPlayer`) para que la
  navegación no dependa de las vistas concretas.

Ya aplicado en las SIETE vistas partidas: `PaginaHome` → `HomeTv` (nav arriba
+ IndexedStack + miniplayer ancho) / `HomeEscritorio` (sidebar 240px) /
`HomeMovil` (PageView + navbar flotante); y lo mismo en Búsqueda, Inicio
(feed), Mi Espacio, Splash, Setup y Tutorial (`<x>_tv` / `<x>_escritorio` /
`<x>_movil`).

Ya aplicado también en las tres que faltaban y que antes eran de UNA sola
variante: **detalle** (`detalle/comun/vistas/detalle_{tv,escritorio,movil}.dart`,
compartido por álbum/artista/playlist), **reproductor**
(`reproductor/vistas/reproductor_{tv,escritorio,movil}.dart`) y **Ajustes**
(`ajustes/sheet/vistas/{tv,escritorio,movil}` sobre `ajustes_marco.dart`).

PENDIENTE: el **tutorial interactivo** (el overlay de pasos) sigue siendo de una
sola forma; su capa se dibuja en el Overlay raíz, así que partirla pide otra
estrategia que la de una página común.

### Vistas (features/) — empezando por el Splash

Se creó la estructura de vistas globalizada en `lib-nuevo`:

```
l10n/                            — AppLocalizations + strings ES/EN (copiados tal cual: son datos)
shared/tema/colores_app.dart     — paleta global (ex AppColors)
shared/tema/envoltorio_color_dinamico.dart — Material You (ex DynamicColorWrapper)
shared/constantes/constantes_fuente.dart   — iconos/etiquetas de proveedores (ex source_constants)
shared/utilidades/responsive.dart          — escalado responsive (ex Responsive)
shared/utilidades/formato_tamano.dart      — KB/MB legible (ex formatBytes)
shared/utilidades/nombres_aleatorios.dart  — usernames sugeridos (ex randomNames)
shared/utilidades/haptico.dart             — feedback háptico (ex Haptic)
shared/widgets/contenedor_vidrio.dart      — glassmorphism (ex GlassContainer)
shared/widgets/boton_vidrio.dart           — botón glass (ex GlassButton)
shared/widgets/estado_vacio_animado.dart   — estado vacío animado (ex AnimatedEmptyState)
shared/widgets/fondo_particulas.dart       — partículas de notas (+ part partícula)
features/splash/ — bloc (estado/evento/bloc) + pagina_splash + widgets (logo, error)
```

- **Regla aplicada:** todo lo que es presentación/plataforma se queda en
  Flutter y se globaliza en `shared/` (una sola implementación reutilizada por
  todas las vistas) — nada se duplica entre features.
- **Splash migrado completo:** `PaginaSplash` + `SplashBloc` + `EstadoSplash`
  + `EventoSplash` + `LogoPulsante` + `PanelError`, todos ≤150 líneas, con
  nombres en español y cabeceras con flujo. Usa `BackendService.healthCheck()`
  y `CacheAjustes.cargarDatosSetup()` ya migrados.
- **Excepción a la regla de 150 líneas:** `l10n/strings/onboarding/strings_setup.dart`
  (816 líneas) es solo datos de traducción ES/EN, igual que los archivos
  generados por drift.
- **Limpieza previa:** 8 archivos muertos eliminados de `lib/` (ver arriba).

### Splash y Setup — doble variante (móvil/escritorio) aplicada

- **Splash dividido en 3 variantes + selector:** `pagina/pagina_splash.dart`
  (selector con la lógica de estado/navegación), `vistas/splash_movil.dart`
  (diseño actual con logo pulsante), `vistas/splash_escritorio.dart` (panel de
  vidrio centrado, layout horizontal) y `vistas/splash_tv.dart` (sin partículas).
- **Setup completo migrado:** bloc (estado/evento/manejadores/avanzado +
  part de persistencia), 10 slides + sub-widgets en `widgets/`, y la página
  en 4 archivos: `pagina/pagina_setup.dart` (selector + diálogo info + creación
  del estado), `vistas/setup_movil.dart` (AnimatedSwitcher, ancho máx 560px),
  `vistas/setup_escritorio.dart` (panel vidrio 620px + indicador de pasos) y
  `vistas/setup_tv.dart` (panel más ancho).
- **Globalizado (sin duplicación):** `widgets/construir_paso.dart` — el switch
  de pasos → slide es UNO SOLO, compartido por móvil y escritorio.
- **Aprendizajes de esta tanda:** (1) un mixin no puede usar un getter de
  otro mixin a menos que se declare `on` ese mixin (`ManejadoresSetupAvanzado
  on ManejadoresSetup`); (2) `setState` es protegido → los parts usan un
  wrapper público `_aplicar(VoidCallback fn) => setState(fn);` en el State;
  (3) los parts de widgets reciben el widget (`SlideModo w`) o el State
  (`_SlideXState st`) como parámetro para acceder a sus campos privados.

### Búsqueda — vista completa con doble variante

La vista de búsqueda (SearchPage + SearchResults + SearchBloc originales:
~1,200 líneas) se migró completa con patrón Bloc y doble variante:

```
features/busqueda/            — bloc (5) + página (4) + variantes (2) + widgets (10)
shared/widgets/acordeon_fuente.dart       — selector de extensión (ex SourceAccordion)
shared/widgets/hoja_opciones_descarga*.dart — hoja de calidad (ex DownloadOptionsSheet, 613 líneas → 6 archivos)
shared/widgets/modales/info_cancion/      — info del ítem (ex SongInfoModal)
shared/widgets/modales/agregar_a/         — agregar a playlist/favs/cola (ex AddToModal)
shared/widgets/modales/playlist/          — hoja de playlist: crear/editar (8 archivos)
  hoja_playlist                            — entrada, widget y estado (136 líneas)
  hoja_playlist_acciones                   — cargar/agregar/quitar/portada/guardar (part)
  hoja_playlist_cabecera                   — tirador + título + portada y nombre (part)
  hoja_playlist_cuerpo                     — alto del panel, fondo reactivo y piezas (part)
  hoja_playlist_canciones                  — atajos Me gustan / Descargadas (part)
  hoja_playlist_lista                      — lista de canciones con quitar (part)
  hoja_playlist_vacio                      — estado vacío (con scroll, sin overflow) (part)
  hoja_playlist_portada                    — selector de foto de portada (part)
shared/widgets/vidrio/fondo_reactivo_portada.dart — fondo de modal reactivo a la carátula
core/servicios/playlist/editor_playlist*.dart — guardar playlist + biblioteca local
core/servicios/playlist/fuentes_playlist.dart — likeadas/descargadas para armar playlists
core/modelos/playlist/playlist_propia.dart — PlaylistPropia (id, nombre, portada, canciones)
shared/widgets/transiciones_pagina.dart   — rutas fade/slide (ex PageTransitions)
shared/utilidades/acciones_item*.dart     — ItemActions globalizado (una sola impl para feed/search/miespacio)
```

- **Bloc:** `BlocBusqueda` + estado/eventos con cache LRU, streaming y
  verificación de sesión firmada para fuentes que la requieren (qobuz/amazon).
- **Cero duplicación:** la lógica (debounce, fuente persistida en drift via
  `CacheAjustes`, re-consultas por categoría) vive en `pagina_busqueda.dart` +
  parts; las variantes móvil/escritorio solo reciben barra/chips/cuerpo
  armados y las colocan (móvil: columna full-width; escritorio: panel 680px).
- **Acciones globalizadas:** `AccionesItem` centraliza like, descarga
  (individual/lote), borrar, exportar playlist (fetch detalle a Go + M3U/CUE)
  e info/más — Feed y MiEspacio lo reutilizarán sin duplicar.
- **Detalle migrado:** `features/detalle/` — `AlbumDetallePagina`,
  `PlaylistDetallePagina` y `ArtistaDetallePagina` (carga memoria→local→
  API→lote offline) con `CabeceraDetalle` compartida, botón vidrio único
  (`boton_accion_vidrio`) y exportación de playlist vía `exportarConSnack`.
  `navegador_detalle.dart` ya navega a las páginas reales y `onNavegarItem`
  está cableado en Feed y Búsqueda desde el ensamblador.
- **Reproductor migrado:** `features/reproductor/` — `ReproductorPagina`
  (NowPlaying: portada/video visualizador, swipe-down, velocidad),
  `hoja_letras` (karaoke LRC con paleta de carátula), `modal_cola`
  (reordenable) y el miniplayer conectado vía `RutaDeslizarArriba`.
  `paleta_portada` migra el cover-palette WCAG en español.
- **Aprendizajes de esta tanda:** los parts comparten los imports de la
  library principal (si el part usa un tipo, el import va en el principal);
  los estáticos privados se acceden con la clase desde el part
  (`_HojaOpcionesDescargaState._calidades`); las funciones top-level del part
  que mutan el State usan el wrapper `_aplicar` y reciben el State.
  `dart analyze lib-nuevo` sigue en **0 issues** y todo ≤150 líneas.

### Feed — vista completa con doble variante

La vista de inicio (FeedPage + FeedContent + FeedBloc originales: ~730 líneas)
se migró completa con patrón Bloc y doble variante:

```
features/feed/
├── bloc/
│   ├── feed_bloc.dart      # Bloc (eventos → estado)
│   ├── feed_cache.dart     #   part: carga cache-primero + refresh + guardado
│   ├── feed_estado.dart    # Estado (secciones, fuente, usuario, error)
│   └── feed_evento.dart    # Eventos (cargar, descargar, cambiar fuente)
├── feed_pagina.dart        # Página: lógica + selector variante
│   ├── feed_pagina_helpers.dart # part: fuentes disponibles + acciones
│   └── feed_pagina_widgets.dart # part: cabecera/cuerpo armados
├── feed_movil.dart         # Variante CELULAR (diseño actual)
├── feed_escritorio.dart    # Variante ESCRITORIO (panel 680px)
└── widgets/
    ├── cabecera_feed.dart        # Saludo por hora + username + selector fuente
    ├── contenido_feed.dart       # Cuerpo (loading/vacío/lista + refresh) + snapshot
    ├── contenido_feed_tarjetas.dart # Tracks (máx 10/sección) + estado descarga
    ├── contenido_feed_grillas.dart  # Grillas responsivas + cabecera de sección
    └── contenido_feed_estado.dart   # Estado vacío (sin contenido)
```

- **Cache offline:** `BlocFeed` restaura el último feed guardado al instante y
  refresca en background sin vaciar lo visible (igual que el original).
- **Selector de fuente inteligente:** las burbujas salen SOLO de las secciones
  que Go devolvió con contenido (evita duplicados y fuentes sin getHomeFeed).
- **Reutiliza toda la base compartida:** tarjeta_track, tarjeta_grilla,
  esqueleto (EsqueletoFeed), acordeon_fuente y AccionesItem — cero duplicación.

### Home — ensamblada y cableada al shell

- **`features/home/ensamblador_home.dart`** crea `BlocBusqueda` + `BlocFeed`,
  provee los cubits globales en el árbol y construye los 4 slots del shell:
  `buscador` (PaginaBusqueda), `feed` (PaginaFeed), `miEspacio`
  (PaginaMiEspacio real) y `miniPlayer` (Miniplayer real con animación).
  Dispara `CargarFeed` al montar.
- **`inyeccion.dart`** registra los cubits globales: `CubitCola`, `CubitLikes`,
  `CubitDescargas`, `CubitPlaylists` (+ `ServicioDominioPlaylist`) y
  `CubitReproductor`.
- **Mi Espacio migrado (19 archivos):** `modelos_item`, `datos_mi_espacio`
  (+ items/items2), `pestanas_mi_espacio`, `perfil_mi_espacio`
  (+ avatar/piezas/hoja_ajustes), `contenido_mi_espacio`
  (+ canciones/grilla/helpers/vacio/widgets) y `pagina_mi_espacio`
  (+ acciones/banner/helpers/widgets) con doble variante móvil/escritorio.
  Reutiliza `TarjetaTrack`/`TarjetaGrilla`/`AccionesItem`/`mostrarHojaPlaylist`
  (hoja compartida de playlist) y el navegador de detalle (stub).

### Playlist: crear y editar en una hoja (reemplaza al diálogo flotante)

- **`mostrarHojaPlaylist(context, {playlistId, semilla, sobreHoja})`** es la
  única entrada: en Mi Espacio crea, desde el detalle edita (nombre, portada y
  canciones) y desde "agregar a" crea con la canción ya cargada. `sobreHoja`
  va en true cuando sale desde otro modal, para que su velo tape el de abajo.
- **Portada:** `shared/utilidades/portada/portada_playlist.dart` copia la foto
  elegida a `<documentos>/portadas_playlist` (la ruta del selector de Android
  es temporal y quedaba muerta). Sin foto, la playlist usa la carátula de su
  primera canción.
- **`ServicioEditorPlaylist.guardar`** deja las canciones EXACTAS en orden
  (`CollectionsDao.reordenarItems` escribe `position`, que `addTrack` no tocaba)
  y sincroniza cada canción a la biblioteca local (artista + `tracks`), sin
  pisar portada/letra/video ya descargados: `collection_items` solo guarda ids,
  así que una canción ausente de `tracks` no tenía ni nombre ni artista.
- **Detalle de playlist local** ahora resuelve `artistName` y `albumName`
  (antes la playlist propia mostraba las canciones sin intérprete).
- **Hojas no flotantes:** Material 3 limita las hojas a 640 px y las centra en
  pantallas anchas (PC/TV); `mostrarHoja` las abre sin tope de ancho.
- **"Agregar a playlist" lista MIS creadas:** el selector lee
  `CacheColecciones.getPlaylistsPropias()` (las `col_*` con portada y conteo, en
  una sola consulta agrupada), y suma con `ServicioEditorPlaylist.agregarItem`
  (al final, sin duplicar y dejando la canción en la biblioteca).
- **Cubits desde DI dentro de los modales:** una hoja vive en el `Navigator`
  raíz, POR ENCIMA de los providers de la Home, así que `context.read<CubitLikes>()`
  tiraba `ProviderNotFoundException` y el tap no hacía nada ("Me gustan" y el
  corazón de "agregar a"). Ahora usan `sl<...>()`.
- **Likeadas/descargadas desde la BASE:** los atajos de la hoja de playlist
  piden las canciones a `FuentesPlaylist` (drift) y no al estado en memoria de
  los cubits, que se carga async al arrancar: antes, abrir el armado apenas
  arrancaba la app (o tener más de 100 descargas) sumaba cero canciones sin
  decir nada. Además el chip muestra un spinner mientras lee y avisa si no había
  nada que sumar. Lo cubre `test/widgets/hoja_playlist_fuentes_test.dart`, que
  monta la hoja sin ningún provider y con los datos solo en la base.
- **La portada que le pusiste a una playlist manda:** el detalle resolvía
  primero la carátula del like y después la del lote de descarga, así que una
  playlist con el corazón (o descargada) mostraba el arte del proveedor y "se
  comía" la foto elegida. `mejorCaratulaPlaylist` (en `caratula_util.dart`)
  pone la propia (foto o portada sincronizada) por delante. Cubierto por
  `test/unit/caratula_playlist_test.dart`.
- **La foto elegida se copia a la app:** la ruta que devuelve el selector vive
  en la caché del plugin (se puede borrar) y en modo SAF puede venir vacía; si
  venía vacía se perdía en silencio. `portada_playlist.dart` la copia a
  `portadas_playlist/` y conserva la extensión (`test/unit/portada_playlist_test.dart`).
- **Un solo fondo reactivo:** `FondoReactivoPortada` (portada desenfocada +
  velo, o el color dominante en modo Spotify) reemplaza las copias privadas del
  karaoke, la cola, "agregar a", info de canción y la hoja de descarga; también
  lo usan la hoja de playlist y el selector de playlists.

### Diseño POR VISTA + tipografía (v1.0.0) — el motor del "santo grial"

El diseño dejó de ser UNO para toda la app: cada vista puede salirse y las demás
heredan. Dos piezas nuevas, las dos con el mismo criterio de "lo que no toca, no
cambia":

```
core/modelos/usuario/disenos/vistas/vista_app.dart            — las 7 vistas (clave estable)
core/modelos/usuario/disenos/vistas/diseno_vista.dart         — qué sobrescribe cada uno
core/modelos/usuario/disenos/vistas/preferencias_vistas.dart  — el mapa (solo lo tocado)
core/modelos/usuario/disenos/vistas/preferencias_vistas_json.dart — codec tolerante
shared/utilidades/formato/apariencia/vistas/apariencia_vistas_helper.dart — la cascada
core/modelos/usuario/fuentes/{fuente_app,catalogo_fuentes}.dart — catálogo de tipografías
core/servicios/fuentes/servicio_fuentes.dart                  — baja, registra y publica
core/backend_go/.../infra_mixin.dart (descargarFuente)        — puerta al backend
```

- **La cascada es `vista → global → fábrica`.** `AparienciaVistas.de(context,
vista)` devuelve valores YA resueltos (nada en null): lo que declara la vista, o
si no el estilo global del usuario, o si no el de fábrica. Es lo que permite
personalización extrema sin que la app quede incoherente: el que no entra a
Ajustes ve todo como siempre.
- **Solo se persiste lo TOCADO.** `PreferenciasVistas` guarda nada más las
vistas personalizadas, así que agregar una vista nueva en el futuro no obliga a
migrar nada y "Restablecer" no deja entradas fantasma.
- **La tipografía estaba empaquetada y SIN USAR.** `assets/fonts/GoogleSansFlex.ttf`
viajaba en cada build pero `EnvoltorioColorDinamico` armaba el `ThemeData` sin
`fontFamily`: toda la app se dibujaba con la tipografía del sistema. Ahora el
tema la declara y `ServicioFuentes` publica la familia activa por un notifier
(`ValueNotifier<String?>`) para que el repintado llegue sin reiniciar.
- **Una bajada fallida nunca deja la app sin tipografía.** Si el backend no
responde (binario viejo, espejo caído, sin red) se vuelve a la empaquetada y se
informa el estado; `ServicioFuentes.estado` es lo que lee Ajustes. En web se usa
la empaquetada a propósito: la ruta que devuelve el backend remoto no es un
archivo de ESTE dispositivo.
- **El backend valida antes de guardar:** id como nombre de archivo seguro
(`^[a-z0-9_]{1,32}$` — sin eso un `../` escribe fuera de la carpeta), firma sfnt
(un portal cautivo que contesta 200 con HTML no se guarda como `.ttf`), sha256
opcional, tope de 16 MB y escritura atómica (temporal + rename).

### El ÁMBITO por vista: cómo llega el diseño a las cards sin tocarlas

Resuelto el modelo, faltaba lo difícil: que una card de adentro de una vista
obedezca a ESA vista sin que cada tarjeta sepa que existen las vistas. La
solución es un `InheritedWidget`:

```
shared/widgets/vista/base/ambito_vista.dart   — el ámbito (lleva declarado + resuelto)
shared/widgets/vista/base/diseno_de_vista.dart — quien lo monta y resuelve la cascada
shared/utilidades/formato/apariencia/barras/apariencia_espacios_helper.dart — quien lo LEE
```

- **Cada eje necesita su CONSUMIDOR, si no el control miente.** El redondeo y el
  aire llegan solos por `AparienciaEspacios`; las columnas necesitaron extraer
  la cuenta que estaba **copiada en tres grillas** (feed, búsqueda y mi espacio:
  2/3/4/6 según el ancho) a `vistas/grilla_vista.dart`. De paso: tres copias de
  la misma fórmula es la forma más segura de que dos queden viejas.
- **Las columnas no heredan del global**, a diferencia del resto: no hay un
  "columnas del estilo global", las decide el ancho de la pantalla. Por eso su
  marca dice "Automático" y no "Heredado", y el tope **sólo puede reducir**
  (pedirle 6 columnas a un cajón de 400 px daría portadas del tamaño de un
  sello). `_VistasEje` acepta `marcaVacia` justo para eso.
- **Se envuelve UNA vez por vista** y de ahí para adentro todo obedece:
  `ensamblador_home` (buscador/feed/mi espacio/reproductor), `navegador_detalle`
  (las tres de detalle), `showSettingsSheet` (la hoja entera) y `TutorialPagina`.
- **El truco está en `AparienciaEspacios`.** Las cards ya pedían
  `radioCards(context)` y `espacioXCancion(context)`; esos getters ahora pasan
  por el ámbito, así que la personalización por vista llegó a TODAS las cards y
  grillas **sin tocar una sola tarjeta**. Si mañana se agrega una card nueva,
  hereda el comportamiento sola.
- **El ámbito guarda las DOS caras:** `declarado` (lo que la vista pidió, para
  saber si eligió algo propio) y `resuelto` (lo que hay que pintar). Con sólo el
  resuelto no se podría distinguir "heredó el radio global" de "eligió justo
  ese radio", y el control de Ajustes no sabría si marcar "Heredado" o "Propio".
- **`DisenoDeVista` es `StatefulWidget` a propósito:** escucha la preferencia por
  vista, la global y el registro de familias tipográficas, y así repinta cuando
  cualquiera cambia (un `ValueListenableBuilder` anidado tres veces sería peor).
- **La densidad MULTIPLICA, no reemplaza** (`base * densidad`): mover el control
  general sigue moviendo todas las vistas juntas y la que se aparta lo hace en su
  medida. Con un reemplazo, personalizar una vista la desconectaría del control
  global para siempre.

**Aprendizaje de esta tanda:** una fuente elegida por vista necesita su propio
camino de carga. `activar()` cambia la tipografía GLOBAL, así que se agregó
`asegurarFamilia()` (baja y registra sin publicar familia ni estado) más un
`ValueNotifier` de generación para que la vista repinte cuando el `.ttf` termina
de llegar. Sin eso, la vista elegía otra letra y seguía mostrando la vieja hasta
el próximo repintado de casualidad.

### El COLOR por vista: el cofre tiñe las cards de esa pantalla

Es el primer eje por vista que **pinta** (los demás mueven medidas) y el único
que no tiene equivalente global: el cofre vive en las barras, así que una paleta
solo puede ser de una vista.

```
shared/utilidades/formato/apariencia/vistas/tinte_vista_helper.dart — las reglas del tinte
```

- **La paleta MANDA sobre el color de la carátula.** El acento de una card salía
  siempre de `EstiloHelper` + el dominante del cover; ahora
  `TinteVista.acentoDeCards(context, delCover)` deja ganar a la vista. Si el
  cover pudiera pisarla, elegir una paleta no serviría de nada.
- **Tiene PISO de intensidad (0.6).** El tinte se apaga con el deslizador de
  Estilo; si una paleta elegida con ese control en 0 no se viera, sería un
  control que miente. Por encima del piso, el deslizador sigue mandando.
- **Con paleta NO se extrae el dominante del cover** (`TinteVista.
  extraerDelCover`). Beneficio gratis: se evita esa decodificación por tarjeta en
  toda la pantalla.
- **Una sola intensidad por pantalla.** El espaciado de las grillas se CIERRA a
  medida que crece la intensidad del color, así que la grilla tiene que medir lo
  mismo que sus cards: `TinteVista.nivelDeGrilla`. Antes medía el global y con
  una paleta puesta las cards salían teñidas y la grilla con el aire de "sin
  color": dos piezas de la misma pantalla diciendo cosas distintas del mismo
  ajuste.
- **Hay cálidos de FÁBRICA (Ámbar y Terracota), abiertos desde el minuto cero.**
  Un catálogo donde todo está con candado se ve roto: el usuario entra, elige un
  color y no cambia nada. El resto de los cálidos (Mandarina 10 h, Brasas
  750 h) sigue en la escalera, así la mitad del catálogo todavía da algo que
  ganar escuchando. El test los verifica **cálidos de verdad** (el rojo pesa más
  que el azul), no por el nombre en el idioma.
- **Un eje por PESTAÑA.** La tarjeta tiene cinco controles —color, letra, forma,
  aire y grilla— y apilados eran un rollo donde había que bajar mucho para
  llegar al último, con cuatro deslizadores juntos sin saber cuál movía qué. La
  tira de pestañas lleva un PUNTO en los ejes que esa pantalla ya tiene propios
  (se ve dónde se salió del diseño general sin abrir una por una) y el selector
  de pantalla y la previa son compartidos: no se elige la pantalla cinco veces.
- **El catálogo de colores va de menos a más horas** y los de fábrica primero,
  así el cofre se lee como una progresión. Un test lo sostiene (`la escalera va
  de menos a más`) y otro verifica que **cada diseño tenga nombre en los dos
  idiomas**: un id sin texto se ve crudo en pantalla ("paleta_ocaso") y eso pasa
  justo cuando se agrega un diseño y se olvida su nombre.
- **Se eligen MIRANDO**: cada paleta es una tarjeta con su muestra en grande, su
  nombre y el estado con el mismo vocabulario que el cofre ("En uso" / "Usar" /
  cómo se abre). Una muestra chica al lado del nombre no deja comparar dos
  paletas.
- **La previa es FIEL:** se dibuja un texto de muestra **en la tipografía de la
  vista**, con su color, su redondeo y su aire en la misma pieza. Cuatro previas
  separadas obligarían al usuario a imaginarse la combinación.
- **Sólo se ofrecen las paletas del cofre**, y del aparato (`coloresParaAparato`),
  con las mismas reglas de apertura que en Barras: lo bloqueado se VE, con
  candado y con cómo se abre —esconderlo dejaría un eje con una sola opción, que
  parece roto—. `disenoId` guarda el id del diseño entero para que el día que la
  forma también se consuma no haya que migrar lo ya guardado.
- **La muestra en vivo también se tiñe** (`_VistasMuestra.paleta`): elegir el
  color y no verlo ahí obligaría a cerrar Ajustes para comprobarlo.

### Guardar y volver a leer: el error que no ve ningún test de modelo

Guardar y leer son dos caminos distintos, y el error clásico es que falte uno de
los dos: se elige, se ve en el momento, y **al reabrir la app volvió todo al
diseño de fábrica**. Ningún test de modelo lo ve (el JSON está perfecto) ni el de
la tarjeta (la elección se ve al instante). Se ve recién al reabrir, así que hay
un test que simula el arranque REAL: notificadores de fábrica y después
`cargarAjustesGuardadosApp` —lo que corre la app al abrir—, y comprueba que los
cinco ejes de la vista vuelven y que una instalación nueva **no** inventa
preferencias que el usuario nunca eligió (`test/unit/ajustes_reinicio_test.dart`).

**Aprendizaje de esta tanda (importante para los tests):** `pumpAndSettle` NO
espera a las consultas reales. La tarjeta de Vistas saca las horas de escucha
—que son las que abren tipografías y paletas— de una consulta a drift, y la zona
de tiempo falso del widget test no avanza el reloj real: la tarjeta se quedaba en
0 horas y la prueba pasaba con el catálogo vacío **por el motivo equivocado** (el
comentario del arnés decía que esperaba la carga async, y no la esperaba). Se
arregla con un turno de reloj real (`tester.runAsync(() => Future.delayed(...))`)
antes de asentar el árbol: ver `asentarDatos` en
`test/widgets/ajustes_apariencia_smoke_test.dart`.

**Aprendizaje de esta tanda (importante para los tests):** `GetIt.reset()` es
ASÍNCRONO. Llamarlo y registrar en la línea siguiente NO alcanza: el reset
pendiente termina después y se lleva puesto el registro, y el test falla con
`type X is not registered` recién cuando aparece un `await` (o sea, casi
siempre). Los `setUp` que resetean tienen que ser `asyn`c y hacer
`await di.sl.reset();` antes de registrar. Se ve en
`test/unit/servicio_fuentes_test.dart` y `test/unit/apariencia_vistas_cascada_test.dart`.

### Geometría del MINIPLAYER (v1.0.0) — tamaño, forma y ancho, con acotadas

El miniplayer tenía UNA sola forma por aparato y los números repartidos en tres
archivos (el celular lo pegaba al borde, la PC le ponía `sobre(18,30)` con
sombra, la tele 22 fijo sin sombra). Con los números en tres lugares, un preset
era imposible: cualquier ajuste se desincronizaba en dos de los tres.

```
shared/utilidades/formato/apariencia/barras/miniplayer_geometria.dart
shared/widgets/reproductor/base/marco_miniplayer.dart               ← margen + tope, compartido por los 3 shells
core/modelos/usuario/preferencias/preferencias_apariencia.dart      ← TamanoMiniplayer / FormaMiniplayer / AnchoMiniplayer
```

- **Los tres shells envuelven el miniplayer con `MarcoMiniplayer`.** Antes cada
  uno escribía sus márgenes a mano (celular 0, PC `sobre(18,30)`, tele 22): con
  el tope de ancho, repetir la cuenta en tres lugares es garantía de que dos
  queden mal. El marco toca SÓLO el eje horizontal (el vertical sigue siendo de
  cada shell: no es lo mismo la barra pegada a la navbar que la tarjeta con
  aire de la PC) y va por FUERA del adorno del shell (borde, sombra, esquinas):
  si el ancho se acotara por dentro, la tarjeta seguiría ocupando la pantalla
  entera con una barrita centrada adentro.
- **`AnchoMiniplayer.auto` es un MÁXIMO, no un objetivo:** sólo acota arriba de
  su tope (1600), así que en un monitor normal no cambia absolutamente nada. La
  barra acotada va centrada; con el preset de fábrica la app se ve igual.
- **El relleno interno se mide contra la BARRA, no contra la pantalla.** El
  miniplayer usaba `r.width * 0.04`: el 4% de una pantalla de 3840 son 153 px y,
  dentro de una barra acotada a 1600, se comía el contenido. Ahora es el 4% de
  la pantalla **acotado al 8% de la barra** (en un celular da 15.6, igual que
  antes).
- **Los chips de "Automático" dicen a qué equivalen** (`Automático · Pegado al
  borde`, `Automático · Ancho completo`). Sin eso el usuario elige el preset de
  fábrica, no ve ningún cambio en su pantalla y parece que el control está
  roto — que es exactamente el caso de `auto` en la mayoría de los aparatos.

- **Los presets multiplican las medidas base del aparato, no las reemplazan.**
  Con `normal` + `auto` los números salen **exactamente** como antes: el que no
  toca nada ve la app de siempre. Por eso `calcular` recibe `baseCaratula`,
  `baseRadioCaratula` y `baseMargen` (lo de HOY) en vez de inventarlos.
- **`FormaMiniplayer.auto` existe a propósito.** El default no es un valor sino
  "la de siempre en este aparato": pegado en el celular (si no queda un hueco
  contra la navbar) y flotante en PC/TV. Un default plano obligaba a elegir
  mal en dos de los tres aparatos.
- **Las acotadas son la razón de que sea una función PURA** y no una cuenta
  suelta en cada shell. El margen nunca pasa el 6% del ancho y la carátula el
  22%: con "grande" en una ventana angosta, la carátula se comía el título y
  los controles. Los iconos crecen menos que la carátula, por lo mismo.
- **`_acotarArriba` resuelve `max <= min`.** En una ventana más angosta que
  2× el margen mínimo, el `clamp` de Dart tira excepción cuando el mínimo queda
  arriba del máximo: ahí manda el techo, porque en una pantalla así de chica
  cualquier margen es peor que el piso.
- **La sombra es parte de la forma flotante**, no del aparato: si el usuario
  elige "pegado al borde", no hay dónde caer. (La tele nunca la lleva: se
  recompone en cada frame y a metros no se ve.)

**Aprendizaje de esta tanda:** un ternario donde una rama es `0` (int) y la otra
un `double` se infiere **`num`**, y después no entra en un campo `double`. La
solución es el tipo explícito (`final double margen = ...`), no castear después.**Aprendizaje de esta tanda:** `json['x'] as String?` **NO es tolerante**: tira
`type 'int' is not a subtype of type 'String?'` si el valor guardado es un
número. En un codec que existe para no romper el arranque, hay que preguntar por
el tipo (`json[clave] is String`) en vez de castear. Lo cubren
`test/unit/miniplayer_geometria_test.dart` y `test/widgets/ajustes_apariencia_smoke_test.dart`.

### Peso del APK (v1.0.0) — R8, la tipografía, el QR y los carruseles

La app bajó **~10 MB por APK (−21% en x86_64, −27% en arm64)** sin perder nada
visible. Las tres palancas grandes, en orden de tamaño:

```
android/app/build.gradle.kts     ← isMinifyEnabled = true (R8)
android/app/proguard-rules.pro   ← las reglas que hacen que R8 no rompa JNI/manifest
assets/fonts/GoogleSansFlex.ttf  ← 4,15 MB → 0,28 MB (sólo los ejes que la app usa)
scripts/build/optimizar_fuente.py + verificar_fuente.py
lib/features/ajustes/sheet/conexion/qr/base/lector_qr.dart   ← QR sin ML Kit
```

- **R8 (minify) encendido** ahorra **~4,9 MB** de dex, y `shrinkResources` queda
  APAGADO a propósito: `res/` entera pesa 0,6 MB y los PNG de banderas se buscan
  **por nombre** en tiempo de ejecución, así que sacarlos rompe sin ahorrar casi
  nada. Las reglas de `proguard-rules.pro` conservan nativos, anotaciones y las
  clases del manifest: sin ellas la app se clavaba en el splash (todo JNI/reflexión
  se renombra a `a.b.c`).
- **ffmpeg-kit NO es `com.arthenica.ffmpegkit`.** El fork que se usa
  (`ffmpeg_kit_flutter_new_audio`) declara el paquete
  **`com.antonkarpenko.ffmpegkit`**. Se descubrió en el logcat
  (`FFmpegKitFlutterPlugin created com.antonkarpenko.ffmpegkit.FFmpegKitFlutterPlugin`),
  no leyendo el pubspec. Las dos reglas quedaron puestas, por las dudas.
- **La tipografía pesaba 4,15 MB y NO era por cantidad de letras** (el archivo
  tenía 535 entradas en el cmap): Google Sans Flex es una VARIABLE con SEIS ejes
  (`opsz, wdth, wght, GRAD, ROND, slnt`) y la app sólo mueve `wght` vía
  `FontWeight`. Fijar los otros cinco en su DEFAULT y dejar `wght` variable lo
  deja en 0,28 MB **sin cambiar un píxel**, porque fijar un eje en su default es
  exactamente cómo se estaba dibujando. `optimizar_fuente.py` lo hace y
  `verificar_fuente.py` lo COMPRUEBA: compara avances y contornos (compilados)
  de la original y la optimizada en cada peso.
- **Generar una estática por peso se midió y se rechazó**: 5 estáticas sumaban
  6,98 MB (cada una repite los contornos completos), más que el original.
- **El QR salió de ML Kit**: `mobile_scanner` se reemplazó por `camera` +
  `zxing2` (puro Dart). Eso sacó 3 bundles nativos del APK (~3 MB):
  `libbarhopper_v3.so` + 3 modelos `.tflite`. `LectorQr.leer` usa el plano Y de
  la cámara como luminancia (con `bytesPorFila`, porque la cámara puede traer
  relleno entre filas) y `HybridBinarizer`, que aguanta luz despareja.

**Medición final** (`flutter build apk --release --split-per-abi`, con
`INCLUDE_X86_64=true`): arm64 36,0 MB · armeabi-v7a 44,7 MB · x86_64 37,7 MB ·
universal 135,3 MB. Sobre el arm64 no se pudo reconstruir un "antes" confiable
(el número que se había anotado salía de un APK **sin** `libapp.so`/`libflutter.so`,
ver abajo); el antes/después medido en x86_64 con la misma receta fue
**50.065.740 → 39.536.068 bytes**.

- **`emulador.sh` arma SÓLO x86_64** (`--target-platform android-x64`) pero
  Gradle igual emite los splits de arm64/armeabi: esos APKs salen **sin
  `libapp.so` ni `libflutter.so`** (el motor sólo se prepara para el target
  pedido) y pesarían ~10 MB menos que los de verdad. No sirven para medir ni
  para instalar en un teléfono: para eso está `scripts/release/release.sh` (y el
  CI), que corren el build completo.
- **Los carruseles de Ajustes son un solo widget compartido**
  (`shared/widgets/carrusel/base/carrusel_ajustes.dart`): cada pestaña pasa sus
  tarjetas y el carrusel pone el aviso de girar, el contador, los puntos y las
  flechas. Con UNA sola página no dibuja nada de sí mismo. Las flechas llevan
  clave propia (`carrusel-anterior` / `carrusel-siguiente`) porque el ícono de
  chevron lo usan un montón de filas de adentro: sin clave, "la flecha de este
  carrusel" no se distingue de la decorativa de una tarjeta.
- **La tarjeta del pool de Qobuz prometía "nunca lanza" y sí lanzaba**: la
  consulta al backend se hacía sin `try`, así que una excepción se escapaba del
  `initState`, la tarjeta quedaba girando para siempre y no se veía ni el estado
  ni el campo para pegar la URL propia. Una respuesta `null` ya es el estado de
  error, así que el fallo ahora se cuenta como respuesta inválida.
- **Todo lo que gira lo cubre la prueba**: un `testWidgets` por pestaña
  (`otrosCarruseles` en `test/widgets/ajustes_apariencia_smoke_test.dart`)
  verifica que exista el carrusel de esa pestaña, que arranque en el primero con
  su contador, que esté el aviso de girar y que se llegue a la última página.
  Suite completa: **872 pasan, 2 salteadas**.

**Aprendizajes de esta tanda:**

- Al comparar una fuente variable optimizada hay que **compilarla antes de
  comparar** (guardar y volver a leer). La tabla `glyf` de una variable tiene
  coordenadas en `float` en memoria y recién se redondean al guardar: comparando
  sin compilar aparecen "diferencias" de media milésima que el archivo final
  nunca tiene. Compiladas, quedan diferencias de **≤1 unidad sobre 2000 por em**
  (0,007 px a 14 px) en 4 glifos de 682, y los avances son idénticos: es
  redondeo, no un cambio de dibujo.
- En `fontTools` el default de un eje del `fvar` se lee en `eje.defaultValue`
  (no `eje.default`), y esos valores hay que leerlos DEL ARCHIVO en vez de
  hardcodearlos: si el default cambia, el script tiene que seguir comparando lo
  que la app dibuja de verdad.
- Dentro de una función local de Dart no se puede llamar a otra función local
  **declarada más abajo** (`referenced_before_declaration`): los helpers
  genéricos van primero y los envoltorios (`giraA`) después.

### Huecos con forma (v1.0.0) — 26 spinners menos en toda la app

En Ajustes no queda **ningún** `CircularProgressIndicator` (13 convertidos) y
fuera de Ajustes se convirtieron **otros 13**. Cada lugar donde giraba un círculo
muestra un bloque con la forma de lo que va a aparecer ahí, con las dos formas
nuevas de `shared/widgets/esqueletos/esqueleto_carga.dart`:

- **`EsqueletoEtiqueta`** — barra: el texto de un botón o el valor de una fila.
- **`EsqueletoMarca`** — cuadrado apenas redondeado: el hueco de un ícono (o
  redondo con `radioBorde: lado / 2` para un badge).

- **La forma no es decoración: evita que el layout salte.** Un círculo de 18 px
  donde después va el botón "Limpiar" (72×23) cambiaba el alto de la fila al
  terminar de cargar; con la barra del mismo tamaño la fila se queda quieta.
  Por eso cada hueco copia SU forma y no una genérica: la barra del texto del
  botón (Activando / Enviando / Conectando), el cuadrado del ícono (chevron de
  la carpeta, marca de descarga de la tipografía, refrescar de Qobuz), el
  cuadrado blanco del QR que va a llegar con su código, y la tarjeta entera en
  los tiles que se consultan solos (Google, Soulseek, estado de versión).
- **`sobreColor` es el detalle que se ve a simple vista:** el shimmer del tema
  es blanco al 6%, y encima de un botón relleno verde o rojo eso es invisible.
  Los bloques que van sobre un color piden blanco al 22% (brillo 40%). Los dos
  parámetros nuevos de `EsqueletoCarga` (`color`, `colorBrillo`) son `null` por
  defecto, así que ningún esqueleto que ya existía cambió de color.
- **Cuándo sigue siendo correcto el círculo** (quedan **10**, todos con motivo):
  (1) esperas de arranque donde no hay forma que imitar — el overlay
  "Preparando…" del home, el chequeo inicial del setup, el cuerpo del panel de
  fiesta y la tarjeta "completando la configuración" del setup; (2) **progreso
  de verdad** — el anillo de descarga y la cuenta regresiva usan `value:`, son
  medidores, no placeholders; (3) **buffering** del reproductor (dos lugares),
  que es el único aviso de que el stream va a arrancar; (4) el spinner sobre el
  WebView de verificación, donde lo que viene es una página web, sin forma
  conocida; (5) el "verificando" por proveedor del setup, que es el estado de
  esa fila. La regla completa quedó en la cabecera de `esqueleto_carga.dart`.
- **Los casos nuevos, en una línea cada uno:** lista de canciones de la
  playlist y de Mi Espacio → `EsqueletoFeed` (ya existía, es la misma fila de
  tarjeta); grilla de Mi Espacio → un esqueleto propio con la MISMA cuenta de
  columnas y `childAspectRatio` que la grilla real; selector de playlists →
  filas con portada, nombre y conteo; y en el resto, el hueco del ícono o de la
  etiqueta (letras, traducir, carpeta, guardar, chip de video, cuenta de
  Soulseek en el setup).
- **`BotonVidrio` merece su párrafo**: el estado de carga reemplazaba icono +
  etiqueta con un cuadradito, así que el botón se encogía y volvía a crecer. La
  barra ahora mide **el ancho exacto de la etiqueta**, medido con el mismo
  `TextStyle` (`TextPainter`), así el botón no cambia de tamaño al terminar.
- Lo fijan `test/widgets/esqueleto_formas_test.dart` (6 pruebas: tamaño, radio
  de pastilla vs. radio del botón, marca cuadrada vs. badge redondo, y que
  `sobreColor` cambie el color) y las dos pruebas que antes medían el spinner y
  ahora miden el hueco (`glass_button_test.dart` —incluido que la barra mida lo
  que mide la etiqueta— y `storage_folder_preview_test.dart`).

#### Revisión de los 8 que quedaron: ¿alguno puede ser un medidor honesto?

De los 10 que se habían dejado, **dos se convirtieron** a medidores de verdad y
**dos ya lo eran**; los otros cuatro no tienen nada medible y se quedan
indeterminados a propósito.

- **Verificación del setup → contador real** (`slide_verificacion_widgets.dart`).
  El paso recorre 7 proveedores, uno por uno: había un spinner POR FILA y ningún
  dato de conjunto (siete círculos girando sin saber cuánto falta). Ahora hay
  **"N de 7 verificados" + barra determinada** que salen del estado real de cada
  proveedor (`_estados`), así que avanzan solos. El spinner por fila se fue: cada
  fila ya tenía su propio icono de estado (reloj de arena, sync, tilde, error).
- **Panel del WebView → barra de carga real** (`panel_verificacion_web.dart`).
  El spinner centrado tapaba el dato que el WebView SÍ da: `onProgress` (0-100).
  Ahora es una barra arriba, como el navegador, **determinada** cuando llega el
  avance y sin valor (`value: null`) mientras no haya ningún aviso — que es lo
  honesto en las plataformas que no lo implementan, en vez de mentir con un 0%.
- **Ya eran medidores honestos** y no se tocaron: el anillo de descarga
  (`indicador_descarga_dots`) y la cuenta regresiva del setup
  (`slide_gracias_widgets`) usan `value:`, o sea que miden de verdad.
- **La tarjeta "completando la configuración" del setup NO puede ser un
  medidor.** Se miró a fondo: `_persistirSetup` son unas escrituras locales en
  bucle (`CacheAjustes.completarSetup`) y, si hay código premium, otra escritura
  local (`activarPremium`) — milisegundos, sin etapas que mostrar. Un "3 de 12
  ajustes" sería teatro, no medición: el spinner indeterminado es la respuesta
  correcta para una espera sin progreso observable.
- **Los otros tres tampoco tienen qué medir**: el cuerpo del panel de fiesta
  (espera a que el modo fiesta se inicialice), el chequeo inicial del setup (dos
  lecturas locales) y el **buffering** del reproductor — la app no consume
  `player.stream.buffer`, y "cuánto del stream está bufferizado" no es un
  porcentaje que el usuario pueda interpretar en un botón de play.
- **Hallazgo: el overlay "Preparando tus fuentes…" era código muerto.**
  `PaginaHome.preparando` nunca llegaba en `true` (el ensamblador no lo pasaba),
  así que ese spinner no se veía en ninguna plataforma. Se **borró** (ver
  "Lo que el usuario tenía abierto, sigue abierto").
- Lo cubre `test/widgets/setup_verificacion_medidor_test.dart` (4 pruebas: las
  7 filas, que el medidor no aparezca antes de arrancar, que cuente los
  verificados de verdad —7 de 7, con barra al 100%— y que no vuelva ningún
  spinner por fila).

### Lo que el usuario tenía abierto, sigue abierto (0.9.28)

El fallo que reportó el usuario: *"busco una canción en Mi Espacio, me voy a
Buscar y al volver la búsqueda estaba en blanco"*. No era un problema de Mi
Espacio: era el **shell móvil**.

- **La causa.** La PC y la TV muestran las tres secciones con un `IndexedStack`
  (las deja montadas). El celular usa un **`PageView`**, y un `PageView`
  **descarta** la sección que sale de pantalla: al volver, su `State` nacía de
  cero y con él se iban el texto buscado, la pestaña abierta, los filtros y el
  scroll. Por eso se sentía "en todo lado": pasaba en las tres secciones.
- **El arreglo:** `_SeccionAnimada` (en `home_movil_seccion.dart`) pasó a ser
  `StatefulWidget` con `AutomaticKeepAliveClientMixin` y `wantKeepAlive => true`.
  Es el mecanismo que Flutter tiene para exactamente esto: la sección fuera de
  pantalla no se pinta pero sigue viva. Celular, PC y TV se comportan igual.
- **La prueba no es cosmética: mide nacimientos de `State`.**
  `test/widgets/home_secciones_vivas_test.dart` monta el shell real con tres
  secciones falsas que anotan cuántas veces nació su estado. Cambiar de sección y
  volver tiene que dar **3 nacimientos en total** (una por sección) y los toques
  hechos en Inicio tienen que seguir ahí. Se verificó que **falla** si se pone
  `wantKeepAlive => false` (da 4+), así que no es una prueba que pasa por
  casualidad.
- **De paso: el PageView dejó de reconstruir las tres secciones por frame.** El
  `PageController` notifica en cada frame del gesto, y cada notificación
  reconstruía los tres envoltorios (opacidad + escala). Ahora el envoltorio se
  guarda y se reusa mientras el child sea el mismo y el cambio de opacidad/escala
  quede por debajo de 0,004: devolver la misma instancia hace que Flutter corte
  ahí y no baje al subárbol. Es lo mismo que se veía, con menos trabajo por frame.
- **La pestaña de la Home ahora es compartida por los tres shells.**
  `inyeccion` registraba un `ValueNotifier<int>` "de la pestaña activa" que
  **nadie leía ni escribía**: era un comentario, no una función. Ahora los tres
  shells lo leen al montar (`pestanaHomeInicial`) y lo escriben al cambiar
  (`guardarPestanaHome`), así volver a la Home (enlace compartido, cambio de
  tamaño, remontaje) cae donde el usuario estaba y no siempre en Inicio.
- **Mi Espacio: el texto de la búsqueda ya no vive en la barra.** El acordeón
  monta y desmonta la barra; con el `TextEditingController` adentro, plegarlo
  destruía lo escrito. Ahora el controlador lo presta la página
  (`_ctrlBusqueda`), y plegar el panel **no borra nada**: el texto, el filtro y el
  orden quedan y vuelven a verse al desplegarlo. Además el botón de limpiar
  aparece **con el primer carácter** (antes dependía de que otro widget repintara
  la fila) y limpiar **cancela el debounce** — si no, el filtro que estaba por
  salir volvía a caer después de borrar. Lo fijan las 3 pruebas de
  `test/widgets/mi_espacio_busqueda_barra_test.dart`.
- **Se borró el overlay muerto** "Preparando tus fuentes…":
  `home_movil_overlay.dart`, los parámetros `preparando`/`onSaltarEspera` de
  `PaginaHome`/`HomeMovil` y los dos textos de `StringsNavegacion` que solo
  usaba él. Menos código y una API que ya no promete algo que no hace.

#### ¿"Los ajustes se pierden"? Se auditaron los dos caminos de arranque

Guardar y leer son caminos distintos, y el error clásico es que falte el
segundo —se elige, se ve al instante y al reabrir volvió todo—. Estaba cubierto
el diseño (global y por vista) en `ajustes_reinicio_test.dart`; ahora también:

- **tema e idioma** (los lee `cargarAjustesGuardadosApp`, clave `theme_mode` /
  `locale`) y **perfil de rendimiento + modo fluido** (los lee
  `cargarPerfilRendimiento`, otro camino del arranque: `inyeccion_perfil.dart`).
  El del perfil importa: la elección del usuario tiene que mandar sobre la gama
  detectada, y el modo fluido no puede revertirse solo.
- **Ningún ajuste es "solo escritura".** Se revisó, clave por clave,
  `CacheAjustes` y el API genérico (`guardarAjuste`/`getAjuste`): ruta de
  descargas, ajustes de descarga, datos del setup, estilo, apariencia, vistas,
  perfil, fluido, audio en segundo plano, prioridad de proveedores, historial de
  compartidos, datos de Conexión, token de LAN y credenciales de proveedores —
  **todos** tienen su lectura. Lo único que a propósito **no** se guarda entre
  arranques es la pestaña de Ajustes: la hoja abre siempre en Apariencia (se
  probó recordarla y abría en Descargas "sin motivo", desubicando al usuario).

`lib/features/ajustes/sheet/base/hoja/settings_sheet_sheet_state.dart` quedó
anotado con esa decisión para que no se "arregle" de nuevo.

### El rescate rápido: los canales ahora CORREN, no se suceden (0.9.28)

El rescate de audio por ISRC (`go_backend/internal/provider/flacrescue`) tenía un
defecto de **forma**: recorría sus canales en serie (Qobuz firmado → stash-relay
→ arcod → espejos), así que el tiempo era la **suma** de sus presupuestos —hasta
~17 s— aunque el espejo que sí tenía el FLAC respondiera en 300 ms. Como el
rescate es la PRIMERA fase de la reproducción, ese peor caso se sentía como un
tap roto.

- **El arreglo: `resolucion_carrera.go`.** Todos los canales salen a la vez y
gana el que primero entrega audio. La preferencia ya no se paga **antes** de
empezar, se paga **reteniendo**: un resultado con pérdida espera
`graciaRescateLossless = 1200 ms` a que llegue el sin pérdida que está en vuelo
(ahí hay CALIDAD en juego), y cambiar de canal por uno mejor con la MISMA calidad
espera apenas `graciaRescatePreferencia = 300 ms`. En cuanto los canales mejores
contestan "no tengo nada", el retenido gana **al instante**: esperar la gracia
entera por una fuente que ya dijo que no es lo que se siente como tap muerto. El
`techoRescate = 15 s` es solo la red de seguridad si un canal se cuelga más allá
de su propio contexto.
- **La calidad no se pierde por correr en paralelo.** Es lo que fija
`TestElFLACGanaAlMP3AunqueLlegueDespues`: el espejo tiene MP3 al instante y arcod
el FLAC 600 ms después → suena el FLAC. Y `TestEspejosCorrenJuntoAlCanalLento`
fija el caso real que motivó todo: con arcod colgado, los espejos ganan en
**301 ms** (antes ~1,2 s, porque esperaban a que el canal lento terminara de
fallar).
- **Lo que NO cambió (es lo que sostiene la robustez):** cada canal conserva su
presupuesto, su pausa/backoff y su caché (arcod guarda la puerta del stream que
funcionó; los espejos marcan los suyos sin cuentas y se saltan; el relay cachea
su config 6 h y precalienta en segundo plano); la cascada de FORMATOS de los
espejos sigue siendo serial (FLAC → MP3_320 → MP3_128) y lo paralelo son los
espejos DENTRO de cada formato; y la caché de resolución pasó a tener TTL por
canal (`ttlDeCanal`): el enlace firmado de arcod caduca, una URL de CDN no.
- **Dos arreglos puntuales que se comían cientos de ms por intento:**
  - `arcod_stream.go` comprobaba el enlace firmado (un `Range` de 1 byte) con un
    cliente DIRECTO contra `api.arcod.xyz`, así que con un proxy por región
    configurado el canal creía que el enlace estaba muerto. Ahora usa el
    transporte compartido del rescate (`transporteRescate`), como el resto.
  - `sitios_flac_http.go` dormía `pasoConsultaSitio` **antes de la primera**
    consulta: un peaje fijo de ~900 ms por intento aunque el sitio ya tuviera el
    archivo listo. Ahora la primera va sin espera y el paso se respeta de la
    segunda en adelante.
- **Descargas: los dos caminos de la mejora a FLAC también corren juntos.**
`orchestrator_mejora_flac_bajar.go` resolvía primero los sitios raspables (hasta
45 s de presupuesto) y recién después los espejos/canal sin pérdida: un sitio sin
cuentas arrastraba su espera entera al camino que ya tenía el FLAC. Ahora
`candidatasSitios` y `candidatasEspejos` corren por `resolverEnParalelo` y la
primera candidata que **valida** (FLAC real y de la duración pedida) gana.
- **Una búsqueda de id compartida (esta pasada).** El id de pista de Qobuz lo
necesitan DOS canales (el Qobuz firmado y el stash-relay, que traduce el ISRC por
catálogo) y, al correr a la vez, pagaban la MISMA búsqueda dos veces.
`qobuz_memoria.go` la comparte: el primero la paga, los demás esperan su
resultado (broadcast) y la siguiente vuelta sale de la memoria. **Los fallos NO
se comparten** a propósito: el que esperaba hace su propio intento, porque atar
el destino de un canal al del otro es perder robustez justo donde se necesita.
- **Y un modo de fallo silencioso que quedó cerrado (esta pasada).** Un canal que
contesta "sin error" y con la URL **vacía** era una trampa: el llamador lo
tomaba por un stream, lo cacheaba y el usuario oía silencio sin ningún error. La
carrera lo normaliza a fallo (`contestó sin enlace de audio`) y `resolverPorISRC`
tiene una segunda defensa: nunca devuelve ni cachea un vacío como acierto.
- **La carrera deja UNA línea de log:**
`[rescate] carrera 601ms ganó=arcod canales=4 fallos=[stash-relay: canal apagado | …]`.
Sin eso no había forma de saber, con el log de una app real, si el FLAC vino de
las credenciales, del relay, de arcod o de los espejos, ni cuánto se pagó por él.

Lo cubren, además de las pruebas de red que ya existían,
`resolucion_carrera_test.go` (gana el más rápido · se retiene lo con pérdida por
el FLAC · se suelta apenas no queda nadie mejor · vence la gracia · sin nada
devuelve el error · no se acepta un "éxito" sin URL) y `qobuz_memoria_test.go`
(una sola búsqueda para N canales, memoria entre vueltas y fallos no
compartidos). `TestProxyCubreLaComprobacionDelEnlaceArcod` fija el arreglo del
proxy: se verificó que **falla** sin el transporte compartido.
