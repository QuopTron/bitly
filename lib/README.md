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

### REGLA DE VISTAS: separación PC / celular (obligatoria de aquí en adelante)

Toda vista nueva debe separarse en **dos variantes de layout** y un selector:

```
features/<feature>/pagina_<feature>.dart   → selector: elige según plataforma
features/<feature>/<feature>_movil.dart      → diseño CELULAR (el actual)
features/<feature>/<feature>_escritorio.dart → diseño PC/escritorio (nuevo)
```

- **Celular (Android/iOS/tablet vertical):** el diseño actual — bottom navbar
  flotante, PageView, contenido full-width, modales/hojas.
- **Escritorio (Windows/Linux/macOS/web/pantallas anchas ≥900px):** diseño de
  escritorio — barra lateral fija de navegación, panel de contenido central
  con IndexedStack (secciones vivas), ancho máximo y layout horizontal.
- **Selector ÚNICO:** `usarLayoutEscritorio(context)` de
  `shared/utilidades/deteccion_plataforma.dart` — ninguna vista duplica
  Platform.is* / MediaQuery.width checks.
- **Slots desacoplados:** los shells reciben las páginas internas como
  parámetros (`buscador`, `feed`, `miEspacio`, `miniPlayer`) para que la
  navegación no dependa de las vistas concretas.

Ya aplicado en: `PaginaHome` → `HomeMovil` (PageView + navbar flotante +
miniplayer) vs `HomeEscritorio` (sidebar 240px + IndexedStack + miniplayer).
Las vistas que aún son de una sola variante (p.ej. Splash, Setup, player full
screen) siguen en `pagina_<x>.dart` y solo se dividen cuando tienen sentido
las dos variantes.

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
- **Excepción a la regla de 150 líneas:** `l10n/strings/strings_setup.dart`
  (816 líneas) es solo datos de traducción ES/EN, igual que los archivos
  generados por drift.
- **Limpieza previa:** 8 archivos muertos eliminados de `lib/` (ver arriba).

### Splash y Setup — doble variante (móvil/escritorio) aplicada

- **Splash dividido en 2 variantes + selector:** `pagina_splash.dart` (selector
  con la lógica de estado/navegación), `splash_movil.dart` (diseño actual con
  logo pulsante) y `splash_escritorio.dart` (panel de vidrio centrado, layout
  horizontal).
- **Setup completo migrado:** bloc (estado/evento/manejadores/avanzado +
  part de persistencia), 10 slides + sub-widgets en `widgets/`, y la página
  en 3 archivos: `pagina_setup.dart` (selector + diálogo info + creación del
  estado), `setup_movil.dart` (AnimatedSwitcher, ancho máx 560px) y
  `setup_escritorio.dart` (panel vidrio 620px + indicador de pasos).
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
shared/widgets/modal_info_cancion*.dart   — info del ítem (ex SongInfoModal)
shared/widgets/modal_agregar_a*.dart      — agregar a playlist/favs/cola (ex AddToModal, 348 → 5 archivos)
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
  Reutiliza `TarjetaTrack`/`TarjetaGrilla`/`AccionesItem`/`mostrarCrearPlaylist`
  (diálogo compartido) y el navegador de detalle (stub).