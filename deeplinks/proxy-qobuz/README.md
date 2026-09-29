# Proxy propio de Qobuz (para no exponer a tus usuarios)

## El problema, en una frase

El canal "Qobuz firmado" de la app necesita las claves (`app_id`/`app_secret`) y
la API de Qobuz. Si la app pide las claves a un sitio de terceros, **cada usuario
pega contra ese sitio**: se ve el tráfico, se ve la huella de la app, y un bloqueo
deja a todos sin audio. Y si le pega directo a Qobuz, cada usuario queda expuesto
igual (y no se puede repartir `user_token` sin filtrarlo del teléfono).

## La solución: un Worker tuyo en el medio

`worker.js` es un Cloudflare Worker (una sola función) que:

| Ruta | Qué hace |
|---|---|
| `GET /keys` | devuelve `{appId, appSecret}` **en vivo** (rotación auto-curada; caché de 5 min) |
| `GET /pool` | devuelve el **pool de sesiones** (`QOBUZ_AUTH_TOKENS`): una línea `user_auth_token=<token>` por cuenta |
| `GET /api.json/0.2/*` | reenvía **firmado** a Qobuz, agregando `app_id`, `request_ts` y `request_sig` |
| `POST /premium/<secreto>/verificar` | dice el estado del código en el registro (`activo`/`usado`/`cancelado`/`libre`/`no_encontrado`) |
| `POST /premium/<secreto>/usar` | marca el código como usado (y anota los **firmados** que no estaban, previa verificación de la firma) |
| `POST /premium/<secreto>/reporte` | crea el issue de un reporte de la app (bug/sugerencia) |

## Códigos premium y reportes (`/premium/*`)

El registro de códigos vive en el repo **privado** `QuopTron/bitly_codes_premium`
(`codes.json`). Antes la app lo leía y lo escribía con un **PAT de GitHub
compilado adentro** (`lib/config/secretos.dart`), que salía del APK con
`unzip` + `grep` — y era un token clásico, con acceso a **todos** los repos de la
cuenta. Ahora la llave vive acá, en el entorno del Worker:

```bash
npx wrangler secret put GITHUB_TOKEN      # Contents: Read and write SOLO sobre bitly_codes_premium (+ Issues: write para reportes)
npx wrangler secret put PREMIUM_SECRET    # el secreto que va en la ruta
npx wrangler deploy
```

Y el build de la app inyecta la URL con el secreto en la ruta
(`PREMIUM_REGISTRO_URL=https://<worker>/premium/<secreto>`, ver
`scripts/dev/qobuz_inyeccion.sh`). Sin inyectar, la app **igual valida** los
códigos: la firma de un código se verifica **localmente** (Ed25519 con la clave
pública; ver `go_backend/internal/premium/firmados.go`). El registro es para
confirmar que el código existe y marcarlo como usado, no para validar la firma.

Reglas de convivencia que importan:

- **Si el Worker no responde, nadie se queda sin activar**: el código se activa
  igual y el "marcar usado" queda pendiente en el equipo, que lo reintenta al
  arrancar (`registro_pendiente.go`).
- **El registro solo crece con códigos firmados**: un código `BITLY2.…` cuyo
  firma verifica se anota solo; uno legacy tiene que estar ya anotado (su secreto
  viaja en el binario, así que su firma sola no prueba nada).

Con esto:

- las claves, el pool de sesiones y el `QOBUZ_USER_TOKEN` (si tenés suscripción,
  para FLAC real) **viven en tu Worker**, nunca en el teléfono de los usuarios;
- el tráfico de tus usuarios va a **tu dominio**; Qobuz ve tu Worker, no a cada
  usuario;
- si el secreto rota, se arregla en **un solo lugar**: la app pide claves nuevas
  cuando Qobuz contesta 401, y el Worker las trae de una **fuente viva**, así que
  la rotación se cura sola sin que nadie actualice nada.

## `/pool`: el pool de sesiones que la app ya apunta por defecto

La app ya trae un **origen de fábrica** para `qobuzPoolUrls`
(`sessionpool.QobuzPoolURLsPorDefecto` → `https://qobuz-proxy.guttural-engineer.workers.dev/pool/<secreto>`), así
que un usuario recién instalado no pega nada: baja el pool de tu Worker al arrancar.
Para que eso funcione:

1. Desplegá este Worker (`npx wrangler deploy`) y apuntá ese default a tu
   subdominio (una línea, en `go_backend/internal/sessionpool/qobuz.go`; hoy
   apunta a `https://qobuz-proxy.guttural-engineer.workers.dev/pool/<secreto>`).
2. Cargá `QOBUZ_AUTH_TOKENS` (una o más sesiones de Qobuz, separadas por coma).
3. Verificá: `curl -s https://qobuz-proxy.guttural-engineer.workers.dev/pool/<secreto>`
   → `user_auth_token=<token>` (una línea por cuenta).
4. Si pusiste `QOBUZ_POOL_SECRET`, apuntá el default (o `qobuzPoolUrls`) a
   `https://qobuz-proxy.guttural-engineer.workers.dev/pool/<secreto>`: sin el secreto, `/pool`
   responde `403`.

El formato **no es decorativo**: la app saca las credenciales con
`sessionpool.ExtraerCredencialesQobuz`, que reconoce pares `clave=valor`. Si
sirvieras los tokens sueltos (uno por línea, sin la clave), el pool quedaría vacío
en silencio. El flujo completo está en `selfhost/qobuz-pool/README.md`.

## Despliegue

Con `wrangler.toml` ya en esta carpeta, es un comando (requiere tu cuenta de
Cloudflare, `npx wrangler login` una vez):

```bash
cd deeplinks/proxy-qobuz
npx wrangler deploy
```

Los secretos NO van en `wrangler.toml` (es texto plano): cargalos cifrados una
sola vez por cada uno —

```bash
npx wrangler secret put QOBUZ_APP_SECRET
npx wrangler secret put QOBUZ_AUTH_TOKENS   # tu pool, separado por comas
npx wrangler secret put QOBUZ_POOL_SECRET   # protege /pool
npx wrangler secret put QOBUZ_RELAY_SECRET  # protege /keys y /api.json/0.2/*
npx wrangler secret put QOBUZ_USER_TOKEN    # opcional (suscripción: FLAC)
```

(Sin Wrangler, el mismo resultado pegando `worker.js` en el panel de Workers.)

Variables del Worker:
   - `QOBUZ_APP_ID` (texto — respaldo: se usa sólo si la fuente viva falla)
   - `QOBUZ_APP_SECRET` (secret — respaldo, igual que el anterior)
   - `QOBUZ_LIVE_KEYS_URL` (opcional — fuente viva de claves; por defecto
     `https://flacdownloader.com/api/qobuz/keys`; con `""` se apaga y vuelve a
     la foto fija de `QOBUZ_APP_ID`/`QOBUZ_APP_SECRET`. El nombre lleva `LIVE`
     para no confundirlo con `QOBUZ_KEYS_URL`, que en el build de la app es la URL
     del propio Worker)
   - `QOBUZ_AUTH_TOKENS` (para `/pool` — una o más sesiones, separadas por coma)
   - `QOBUZ_POOL_SECRET` (recomendado — cierra `/pool`; se pasa en la ruta
     `/pool/<secreto>` o en `?s=`)
   - `QOBUZ_USER_TOKEN` (opcional, secret — con cuenta con suscripción: FLAC real)
En la app: **Ajustes → Descargas**, tarjeta *Sesiones de Qobuz* (el estado del
pool) y **Ajustes → Credenciales → Rescate de audio**. Los valores de FÁBRICA ya
apuntan a este Worker, no hay que pegar nada:
   - *Origen de claves Qobuz* (`flacrescue.QobuzKeysURLInyectada`) →
     `https://<worker>/<secreto-relay>/keys`, con el origen de siempre
     (`flacdownloader.com/api/qobuz/keys`) como respaldo;
   - `qobuz_api_base` (`flacrescue.QobuzAPIBaseInyectada`) →
     `https://<worker>/<secreto-relay>/api.json/0.2`;
   - pool (`sessionpool.QobuzPoolURLInyectada`) → `https://<worker>/pool/<secreto>`.

**Ojo**: esas tres NO están escritas en el fuente — se INYECTAN en el build. Ver
la sección de abajo.

El `<secreto-relay>` es `QOBUZ_RELAY_SECRET`: va como PRIMER segmento de la ruta
y cierra `/keys` y `/api.json/0.2/*` (sin él responden `403`). Sin
`QOBUZ_RELAY_SECRET` configurado, ambos quedan abiertos como antes.

Pegá tu propia URL en cualquiera de los dos ajustes para salir del Worker.

Dos cosas que conviene saber del `qobuz_api_base` apuntando acá:
   - **tiene respaldo**: si el Worker contesta 403/429/5xx (cuota diaria agotada,
     relay cerrado con otro secreto, caído) o falla la red, la app reintenta UNA
     vez contra la API de Qobuz directo (`flacrescue.qobuzAPIBaseOficial`), que
     es lo que hacía antes de tener Worker. Se pierde el ocultamiento del
     `app_secret` en esa caída, no el canal;
   - las claves del Worker **no son una foto fija**: `/keys` y la firma del relay
     piden las claves a una fuente viva (por defecto
     `https://flacdownloader.com/api/qobuz/keys`) y sólo caen a
     `QOBUZ_APP_ID`/`QOBUZ_APP_SECRET` si esa fuente falla. Cuando Qobuz rota las
     claves, la app las recibe nuevas en ≤5 min sin tocar el Worker; y si el relay
     firma con una clave que Qobuz ya rechaza (400/401), la recarga y reintenta una
     vez. `QOBUZ_LIVE_KEYS_URL` apunta a otra fuente; `QOBUZ_LIVE_KEYS_URL=""`
     apaga el modo vivo.

Cómo se conecta con la app, en detalle:
   - el token de usuario viaja por CABECERA (`X-User-Auth-Token`). El relay
     **reenvía el que traiga la app** si el Worker no tiene `QOBUZ_USER_TOKEN`;
     así apuntar la app acá no le quita la sesión a nadie.

## Inyectar la config en el build (no se escribe en el fuente)

La URL del Worker lleva su secreto en la ruta: versionarla en el repo pondría el
secreto a la vista de cualquiera que quiera usar (y quemar) tu cuota. Por eso el
fuente NO la lleva, y el build la inyecta con `-ldflags`:

```bash
# 1) Una vez: los valores en qobuz-worker.env (raíz, GITIGNOREADO).
#    QOBUZ_POOL_URL / QOBUZ_KEYS_URL / QOBUZ_API_BASE  (ver el propio archivo)

# 2) Cada build: el helper arma el -ldflags (lee el archivo o las mismas
#    variables de entorno, y el entorno manda).
source scripts/dev/qobuz_inyeccion.sh

# 3) Se compila con eso:
cd go_backend && gomobile bind -target=android -androidapi 24 \
  -ldflags="$QOBUZ_LDFLAGS" -o ../build/bitly-backend.aar .
```

Un build **sin** inyección queda con los defaults públicos: el canal firmado va
DIRECTO a Qobuz y usa el origen público de claves, y el pool de fábrica está
apagado. Es lo que compila cualquiera que clone el repo; tu Worker es opt-in.

En CI, poné `QOBUZ_POOL_URL`, `QOBUZ_KEYS_URL` y `QOBUZ_API_BASE` como
**secrets del repositorio** y corré el helper antes de `gomobile bind`.

Y una verdad incómoda: esto saca la URL de GitHub, pero el APK igual la lleva
adentro (quien lo extráiga la ve). Es ofuscación —sube el costo del abuso casual,
no lo impide. Para eso está el rate limiting del lado del Worker.

## Defensas que ya trae el Worker

| Defensa | Qué hace | Dónde |
|---|---|---|
| `QOBUZ_RELAY_SECRET` | Cierra `/keys` y `/api.json/0.2/*` (sin él: `403`) | primer segmento de la ruta |
| `QOBUZ_POOL_SECRET` | Cierra `/pool` (sin él: `403`) | `/pool/<secreto>` o `?s=` |
| `[[ratelimits]]` (`LIMITADOR`) | 100 peticiones/min por IP en `/keys` y el relay: un abuso no se come la cuota de todos | `wrangler.toml` |
| Cache del edge | `/catalog/search` se guarda 60 s: la misma búsqueda repetida no vuelve a contar | `caches.default` (sólo búsquedas; `getFileUrl` nunca) |
| Claves en vivo | `/keys` y el relay firman con las claves de una fuente viva (no una copia cargada a mano): si Qobuz rota, se curan solas | `clavesQobuz()` en `worker.js` |
| Respaldo a Qobuz directo | Si el Worker da 403/429/5xx o falla la red, la app reintenta contra la API de Qobuz | `flacrescue` (`pedirQobuz`) |

El techo real del plan gratis son **100.000 peticiones/día**; al pasarlas el
Worker deja de responder (no hay exceso facturable). Con el rate limiting y el
cache, llegar ahí requiere abuso deliberado.

## Verificación (offline, sin desplegar)

```bash
node deeplinks/proxy-qobuz/verificar.mjs
```

Comprueba el MD5 hecho a mano contra vectores de `hashlib` (python), que la firma
coincida **con el mismo vector que el backend Go**, el contrato de `/keys` y que el
relay agrega la firma sin dejar salir el `app_secret`.

Es **offline por contrato**: la fuente viva de claves se simula con un `fetch`
de prueba. Las secciones `3b`/`3c` cubren justamente la auto-cura: `/keys` devuelve
la clave viva (y del cache en la segunda petición), una fuente inválida cae al
respaldo, `QOBUZ_LIVE_KEYS_URL=""` vuelve a la foto fija, y el relay reintenta una vez
cuando Qobuz contesta 401 con la clave rotada.

> Este Worker es **opcional**: sin configurar nada, el canal Qobuz queda apagado y
> la app sigue igual que siempre (espejos + YouTube).
