# PO Token de YouTube — qué es, cómo levantarlo y cómo se conecta con la app

> Proveedor local de **PO Token** (bgutil) para que YouTube deje de pedir
> *"Sign in to confirm you're not a bot"* en IPs marcadas, y para que la
> extensión pueda pedir **audio solo-audio** de mejor bitrate en vez del
> `itag=18` (video+audio multiplexado, ~128 kbps) que YouTube entrega sin token.
>
> Estado: **funcionando y verificado** en el emulador (Android x86_64) y en
> desktop. Requisito único: Node.js ≥ 20. **No hace falta Docker.**

---

## 1. Por qué existe

YouTube clasifica por IP. A las IPs "marcadas" (emulador, datacenter, VPN) les
responde en **todos** los clientes InnerTube con el check de bot, y no hay
cuenta ni cookie que lo evite sin iniciar sesión.

Un **PO Token** es una prueba de origen que YouTube emite por video. Se acuña
localmente ejecutando el programa BotGuard de Google (nada de cuentas), y se
manda en la URL del formato:

```
...googlevideo.com/videoplayback?...&pot=<token>
```

Con token, los clientes `android` / `ios` / `mweb` sirven; sin token, el único
formato que YouTube acepta es `itag=18` → **video+audio de 360p**, que es la
causa real de la queja *"YouTube suena mal / no da FLAC"* en enlaces de YouTube.

---

## 2. Cómo lo usa la extensión (`assets/extensions/ytmusic-spotiflac`)

| Pieza | Dónde | Qué hace |
|---|---|---|
| `poTokenMode` | ajuste del manifest, default **`auto`** | `auto` = usar proveedor si hay; `external` = igual; `manual` = token pegado a mano; `off` = no usar nunca |
| `poTokenLocalProviderURLs` | `CONFIG` en `index.js` | endpoints que se prueban si no hay ninguno configurado: `127.0.0.1:4416`, `localhost:4416` y `10.0.2.2:4416` (alias del loopback del PC visto desde el emulador) |
| `requestExternalGvsPoToken` | `index.js` | hace `POST /get_pot`. **Manda `content_binding` (el videoId) PRIMERO**: bgutil 2.x rechaza `visitor_data` con `400 "is deprecated, use content_binding instead"`. Si el primer payload no entra, prueba con `visitor_data` para proveedores viejos (≤1.x) |
| `getGvsPoToken` | `index.js` | cachea el token por `cliente+video` y respeta la caducidad que devuelve el proveedor |
| cooldown de proveedor | `poTokenProviderMarkFail` | un proveedor caído queda **10 min** sin reintentarse: no se paga una conexión fallida por canción |
| `clientesInnerTubeEnOrden` | `index.js` | **con** proveedor disponible, prioriza `android → ios → mweb` (los que traen audio solo-audio); **sin** proveedor, deja el orden clásico (`tv_embedded`, `web_embedded`, …) intacto |

El contrato del proveedor (bgutil 2.x), para debug:

```bash
curl -s -X POST http://127.0.0.1:4416/get_pot \
  -H "Content-Type: application/json" \
  -d '{"content_binding":"dQw4w9WgXcQ"}'
# {"contentBinding":"dQw4w9WgXcQ","poToken":"Mld5...","expiresAt":"..."}   <- camelCase
```

Un `GET /` responde `400` con un texto: **eso significa que el server está vivo**
(no tiene una home útil).

### Diagnóstico en el log del dispositivo

Dos líneas a nivel `warn` (el nivel por defecto; `info`/`debug` **no se ven**):

```
[POT] orden de clientes: modo=auto, proveedores=3 -> se priorizan android/ios/mweb (audio solo-audio)
[POT] PO Token obtenido del proveedor para android (video dQw4w9WgXcQ)
```

Sin la primera no se puede distinguir *"no hay proveedor"*, *"el modo es off"* y
*"el proveedor está pero falla"*: las tres dan el mismo síntoma (`itag=18`).

### Si dice `proveedores=0` y el server está levantado

Nunca hubo un intento: los candidatos locales se descartan ANTES de pedir nada.
La causa que tuvo este bug (y que costó encontrar) fue el **polyfill de `URL`
del sandbox goja**: exponía `protocol` como `"https://"` (con las barras)
cuando el estándar dice `"https:"`. La extensión valida el proveedor con
`parsed.protocol !== "http:"` — como en el navegador — así que descartaba
*todos* los candidatos locales y el proveedor nunca se usaba, en ninguna
plataforma. El mismo polyfill hacía que **Amazon no resolviera ningún enlace**
(`/^https?:$/.test(protocol)` daba false y su `handleUrl` devolvía `null`).

Regresión cubierta por `go_backend/internal/extensions/runtime_url_test.go`,
que evalúa las dos formas exactas que usan las extensiones. Si alguna vez vuelve
a aparecer un `proveedores=0` sin intentos, mirá ahí primero: el harness de Node
no lo puede cazar porque usa el `URL` real del navegador.

---

## 3. Levantarlo (sin Docker)

El proveedor es un programa Node. El repo oficial también publica una imagen,
pero el camino nativo evita instalar Docker.

```bash
# 1) Una sola vez: clonar FUERA del repo (no es parte del proyecto)
git clone --single-branch --branch 2.0.0 --depth 1 \
  https://github.com/Brainicism/bgutil-ytdlp-pot-provider.git \
  ~/bgutil-ytdlp-pot-provider

# 2) Levantarlo (compila la primera vez: npm ci + tsc)
scripts/pot_local.sh

# 3) ¿Está respondiendo?
scripts/pot_local.sh --estado
```

`scripts/pot_local.sh` busca el clon solo (al lado del repo, en `$HOME` o en
`$POT_DIR`), compila si falta y no levanta un segundo server si ya hay uno en
4416.

### Seguridad (importante)

El server **no tiene autenticación** y puede ejecutar JavaScript del BotGuard.
Se levanta con el bind por defecto, que es **solo loopback** (`127.0.0.1` /
`::1`): no queda expuesto a la red local ni a internet. **No le pases
`-H 0.0.0.0`.**

---

## 4. Cómo llega la app al proveedor

| Plataforma | Camino | Nota |
|---|---|---|
| Desktop (Windows/macOS/Linux) | `http://127.0.0.1:4416` | mismo equipo, funciona directo |
| **Emulador Android** | `adb reverse tcp:4416 tcp:4416` | **el recomendado**: el `127.0.0.1:4416` de adentro del emulador pasa a ser el 4416 del PC |
| Emulador Android (alternativa) | `http://10.0.2.2:4416` | alias del loopback del host. En esta máquina el firewall/NAT de Windows lo bloqueó (`HTTP 000`), por eso el camino que funciona es `adb reverse` |
| Teléfono real | — | todavía **no** está resuelto: requeriría el proveedor en la LAN (bind a la IP local) o un proxy. En un teléfono `127.0.0.1` y `10.0.2.2` no existen, así que el sondeo falla rápido y entra en cooldown (no rompe nada, solo no hay token) |

```bash
# Después de cada arranque del emulador (o después de `adb root`, que lo resetea):
adb reverse tcp:4416 tcp:4416
adb reverse --list        # verificar
```

---

## 5. Verificación

```bash
# 1) El server responde y acuña tokens reales
scripts/pot_local.sh --estado
curl -s -X POST http://127.0.0.1:4416/get_pot -H "Content-Type: application/json" \
     -d '{"content_binding":"test123"}'

# 2) Desde ADENTRO del emulador (prueba que el reverse quedó bien)
adb shell "curl -s -m 60 -X POST http://127.0.0.1:4416/get_pot \
  -H 'Content-Type: application/json' --data @-" <<< '{"content_binding":"test123"}'

# 3) Los contratos de la extensión, offline y en CI
scripts/pruebas_extensiones.sh          # incluye ytmusic_pot.js (orden de clientes + token)
```

`scripts/pruebas_extensiones/ytmusic_pot.js` corre en CI y verifica: el contrato
real de bgutil (incluido que rechace `visitor_data`), la prioridad de clientes
con/sin proveedor, que la consecuencia sea la esperada (con token → `itag=251`;
sin token → `itag=18`) y que **las rutas de audio y video no compartan URL**
(sección 8 del harness).

Del lado de Go, la separación de rutas la fija
`go test ./internal/provider/ -run TestRutaDe`: si alguien hiciera que la ruta de
audio pida el formato de video, el test falla con el síntoma escrito en el
mensaje.

---

## 6. Límites conocidos (honestos)

1. **IPs de datacenter**: un PO Token ayuda, no garantiza. YouTube puede seguir
   bloqueando (`yt-dlp` documenta lo mismo). Con token la tasa de éxito sube
   mucho, pero no es 100%.
2. **Sin proxy**: si la IP está marcada a nivel "banned", ni el token alcanza.
3. **En una IP marcada y SIN proveedor, el audio cae igual en `itag=18`.** Eso
   ya no es código nuestro: sin PO token YouTube descarta los formatos
   solo-audio y el único que sirve es el muxed. Con el proveedor arriba, la ruta
   de audio vuelve a los formatos solo-audio (y de eso se encarga el orden de
   clientes de la sección 2). Ningún ajuste lo salva solo: hace falta que el
   proveedor esté alcanzable desde el dispositivo.

## 7. Cómo quedan separadas las rutas (audio vs video)

En Go son caminos distintos desde siempre, y el contrato lo fija un test
(`internal/provider/route_youtube_test.go`):

| Ruta | Quién la pide | Qué pide a la extensión | Formato esperado |
|---|---|---|---|
| **audio** (lo que suena) | `streaming.GetStreamPackage` → `GetStreamURL` | `getDownloadUrl(id, quality)` | solo-audio (251 opus ~160k, 140 m4a ~128k) |
| **video** (visualizador + descarga de video) | `download.ResolveVideoURL` → `GetVisualizerURL` | `getDownloadUrl(id, quality, true)` | `itag=18` (el único con cuadros) |

El tercer argumento (`forceVideo`) es toda la diferencia. Compartir la URL de una
ruta con la otra es exactamente lo que se rompió: la caché **de la extensión**
tenía la clave atada solo al video, así que resolver el visualizador (o un audio
que cayó a `itag=18`) dejaba una entrada que la ruta de audio reutilizaba por 4
minutos → se oía el muxed aunque hubiera proveedor y formatos mejores. Ese era
el "YouTube suena mal" que no dependía de lo que el usuario tocara.

Ahora la clave lleva la ruta (`audio:` / `video:`) y una entrada degradada se
descarta si hay proveedor, a lo sumo una vez por minuto (para no pagar la cadena
de clientes en cada canción). Cubierto por el verificador
`scripts/pruebas_extensiones/ytmusic_pot.js` (sección 8).

---

## 8. Referencias

| Archivo | Qué es |
|---|---|
| `scripts/pot_local.sh` | levanta el proveedor en esta máquina (y `--estado`) |
| `scripts/pruebas_extensiones/ytmusic_pot.js` | verificador del token y del orden de clientes |
| `scripts/pruebas_extensiones.sh` | corre todos los verificadores de extensiones |
| `assets/extensions/ytmusic-spotiflac/index.js` | `getGvsPoToken`, `requestExternalGvsPoToken`, `clientesInnerTubeEnOrden` |
| `assets/extensions/ytmusic-spotiflac/manifest.json` | ajustes `poTokenMode`, `poTokenProviderUrl`, `manualGvsPoToken`, `cobaltApiUrl` |
| `go_backend/internal/download/orchestrator_video.go` | ruta de **video** de Go: `ResolveVideoURL` → `GetVisualizerURL` (itag=18) |
| `go_backend/internal/provider/extension_provider_detail.go` | `GetStreamURL` (audio, sin `forceVideo`) vs `GetVisualizerURL` (video, con `forceVideo`) |
| `go_backend/internal/provider/route_youtube_test.go` | test que fija que el audio NO pida el formato de video |
| `go_backend/internal/streaming/play_package.go` | ruta de **audio** de Go: `GetStreamPackage` → `GetStreamURL` |
