# Mapa del repo — Bitly

Guía de **dónde vive cada cosa** y **cómo trabajar** sin romper nada.
Si vas a mover o agregar archivos, leé la sección [Workflow](#workflow) primero.

---

## Qué es Bitly

App de música (búsqueda, streaming y descarga desde varias fuentes) con
**backend Go embebido** en la app. Corre en Android/TV, Windows, macOS, iOS
y Linux; además hay una **PWA** que usa el mismo backend en modo `--web`.

- `lib/` → app Flutter (todo el código Dart, 557 archivos)
- `go_backend/` → backend Go (motor de fuentes, streaming, descargas)
- El backend se compila y **se embebe** en la app (AAR en Android,
  ejecutable en Windows/macOS/Linux). El usuario no instala nada aparte.

---

## Mapa de la raíz

| Ruta | Qué es |
|---|---|
| `lib/` | App Flutter |
| `go_backend/` | Backend Go (fuente) |
| `assets/` | Recursos empaquetados: `images/`, `fonts/`, `extensions/` |
| `test/` | Tests: `unit/` y `widgets/` (147) |
| `integration_test/` | Tests E2E de dispositivo |
| `docs/` | Documentación (este archivo y notas) |
| `scripts/` | Herramientas: `build/`, `release/`, `pruebas/`, `dev/` |
| `android/` `ios/` `macos/` `windows/` `linux/` `web/` | Proyectos de plataforma |
| `pubspec.yaml` | Dependencias y assets Flutter |
| `build.yaml` | Config de generación de código (`drift_dev`) |
| `Dockerfile` | Backend para self-host |

---

## `lib/` — la app

### Raíz de `lib/`

| Carpeta | Qué contiene |
|---|---|
| `app.dart`, `main.dart` | Entrada y armado de la app |
| `app/` | Inyección de dependencias (`inyeccion.dart`) |
| `router/` | Rutas / navegación |
| `l10n/` | Textos ES/EN (`strings/`) |
| `config/` | Configuración |

### `lib/core/` — base transversal

| Carpeta | Qué contiene |
|---|---|
| `backend_go/` | Puente con el backend Go (`mixins/` con las RPC) |
| `base_datos/` | Drift/SQLite: `daos/`, `tables/` |
| `cache/` | Cachés: `almacenes/`, `estado/`, `reproduccion/` |
| `modelos/` | Modelos de dominio: `detalle/`, `feed/`, `playlist/`, `proveedores/`, `usuario/` |
| `servicios/` | Servicios: `verificacion/`, `oauth/`, `desencriptado/`, `playlist/`, `descarga/`, `utilidades/` |
| `plataforma/` | Integraciones del SO (notificaciones, red, deep links) |
| `audio/` | Motor de audio (interfaz + impls nativa/web) |

### `lib/estado/` — los cubits (máquina de estados)

Una carpeta por cubit. **72 archivos** eran planos; ahora:

| Carpeta | Cubit |
|---|---|
| `descargas/` | `cubit_descargas.dart` (35 archivos) |
| `reproductor/` | `cubit_reproductor.dart` (25) |
| `like/` | `cubit_like.dart` (8) |
| `cola/` | `cubit_cola.dart` (2) |
| `playlists/` | `cubit_playlists.dart` (2) |

### `lib/features/` — las pantallas

| Carpeta | Qué es |
|---|---|
| `home/` | Shell de la Home (móvil/escritorio) |
| `busqueda/` | Pantalla de búsqueda (`bloc/`, `widgets/`) |
| `feed/` | Feed (`bloc/`, `widgets/`) |
| `detalle/` | Detalle de `album/`, `artista/`, `playlist/` |
| `reproductor/` | Reproductor: `pagina/`, `letras/`, `cola/`, `controles/`, `video/` |
| `mi_espacio/` | Biblioteca del usuario: `pagina/`, `contenido/`, `perfil/`, `datos/` |
| `ajustes/` | Ajustes: `sheet/` (secciones) y `update/` |
| `setup/` | Onboarding inicial (`bloc/`, `widgets/{slides,tarjetas}`) |
| `splash/` | Pantalla de arranque (`bloc/`, `widgets/`) |
| `tutorial_interactivo/` | Tutorial estilo Clash Royale (`overlay/`) |
| `tutorial/` | Tutorial antiguo (una sola pantalla) |

### `lib/shared/` — reutilizable

| Carpeta | Qué contiene |
|---|---|
| `widgets/` | Componentes por tipo: `modales/`, `tarjetas/`, `indicadores/`, `esqueletos/`, `fondos/`, `vidrio/`, `base/`, `selector_fuente/`, `reproductor/` |
| `utilidades/` | Helpers (formato, plataforma, paleta, responsivo) |
| `tema/` | Colores y tema |
| `constantes/` | Constantes globales |

---

## `go_backend/` — el backend

| Carpeta | Qué es |
|---|---|
| `cmd/server/` | Entry point del servidor |
| `internal/gobackend/` | API que expone al front (RPC, exports) |
| `internal/extensions/` | Motor de extensiones JS |
| `internal/bundled_extensions/` | Las 9 extensiones embebidas (con `assets_parity_test.go`) |
| `internal/provider/` | Registro y resolución de fuentes |
| `internal/download/`, `internal/drm/` | Descarga y desencriptado |
| `internal/audio/` | Streaming y conversión |
| `internal/cache/`, `internal/cooldown/` | Caché y control de límites |

---

## Convenciones del código

1. **Imports relativos, siempre.** No se usa `package:bitly/...` dentro de `lib/`
   (solo en `test/`). Al mover un archivo, hay que recalcular la ruta relativa.
2. **Arquitectura de `part`.** La unidad real es la **librería** = un archivo
   "padre" (`import`, `class`) + sus `part 'x.dart'`. **Todos los `part` deben
   vivir en la MISMA carpeta que el padre.** Por eso:
   - Se agrupa por **prefijo**: cada `part` comparte el prefijo del padre
     (`tarjeta_track.dart` ↔ `tarjeta_track_cuerpo.dart`).
   - Una librería grande (ej. `ajustes/sheet/`, 49 archivos) **no se puede
     repartir** en subcarpetas: se mueve entera.
3. **Nombres en español** para archivos y carpetas dentro de `lib/`.
4. **Raíz de `lib/` en inglés** (`core`, `features`, `shared`, `estado`).
5. `.md` se ignora por defecto, **salvo `README.md`** (el `!README.md` en
   `.gitignore` permite versionar este archivo y los `README.md` de cada carpeta).

---

## Workflow

### Mover archivos (refactor de estructura)

Mover un archivo **rompe los imports** que lo apuntan. El procedimiento seguro:

1. **Agrupar por prefijo** (nunca partir una librería de su padre).
2. Mover los archivos.
3. **Reescribir imports**: para cada `import`/`export` relativo, resolver el
   destino con la ubicación *vieja* y recalcular la ruta relativa desde la
   ubicación *nueva*. Ojo con los separadores de ruta en Windows al automatizar.
4. Verificar (ver abajo).
5. `git add -A` → git detecta los **renames** (R), no borrados.

### Verificar SIEMPRE después de tocar estructura

```bash
flutter analyze lib test integration_test   # debe decir: No issues found!
flutter test                                # debe decir: All tests passed! (147)
```

Si algo se rompió, los tests lo detectan. Un refactor sin estos dos en verde
**no está terminado**.

### Build y release

| Tarea | Comando |
|---|---|
| APK (Android/TV) | `flutter build apk --split-per-abi` |
| Windows | `flutter build windows` |
| Web (PWA) | `flutter build web --release` |
| Backend Go | `go_backend/build_all.sh` |
| Verificadores de extensiones | `scripts/pruebas/pruebas_extensiones.sh` |
| Release completo | `scripts/release/release.sh` |

El CI (`.github/workflows/`) compila Windows, Android, macOS, iOS y Web en
cada tag. Los binarios van a la **GitHub Release** (nunca al repo).

---

## Notas de investigación (`docs/`)

| Archivo | Qué contiene |
|---|---|
| `knowledge.md` | Conocimiento acumulado del proyecto (decisiones y hallazgos) |
| `extensiones_analisis.md` | Análisis de las extensiones de fuentes |
| `extraccion_music_assistant.md` | Qué se puede extraer del ecosistema `music-assistant` |
| `INSTALAR_EN_TV.md` | Instalación en TV por Downloader |
| `PLAN_TUTORIAL_INTERACTIVO.md` | Plan del tutorial interactivo |
| `01-` a `05-` y `PLAN_MIGRACION_COMPLETO.md` | Historial de la migración |

---

## Notas de higiene (pendientes conocidos)

- **Premium**: el secreto de los códigos está hardcodeado (`checker.go`) y el
  script Python usa otro distinto. Pendiente de migrar a firma asimétrica
  (Ed25519) — ver `scripts/release/generate_keys.py`.
- **Puente Go (`go_backend/bridge_*.go`)**: vive en la raíz de `go_backend/`
  a propósito. `gomobile bind .` deriva el paquete Java del **path** del
  paquete, y `MainActivity.kt` hace `import gobackend.Gobackend`; moverlo
  rompería los bindings nativos de Android/iOS. No reorganizar.
- **`build.yaml`**: apuntaba a `lib/backend/database/` (ruta inexistente);
  corregido a `lib/core/base_datos/`.
- **Stores de sesión** (`*_store.json`): contienen tokens reales; están
  gitignoreados. Nunca commitear.
