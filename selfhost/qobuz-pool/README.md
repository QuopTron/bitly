# Pool propio de Qobuz (self-host mínimo)

Estos archivos **no son de Bitly**: son la guía para levantar el **endpoint que
sirve tus sesiones de Qobuz** y que la app ya apunta **por defecto**. Es el
equivalente de `selfhost/arcod/`, pero para el *pool de cuentas* en vez del
*stream*.

## Por qué existe

El pool de sesiones de Qobuz (`qobuzPool` en la app) vive de credenciales
reales: un `user_auth_token` de una cuenta con **suscripción paga**. No hay pool
público que sirva:

- La API de Qobuz es partner-only y exige plan (Studio/Sublime); no hay endpoint
  de alta ni de emisión anónima de tokens.
- Los pools comunitarios están caídos. Lo dice un proyecto hermano, **FLACidal**,
  en su propia home: *"Community proxies for Tidal, Qobuz and Amazon are mostly
  down right now"*.
- El repo ya había llegado a la misma conclusión (ver el comentario de
  `go_backend/internal/sessionpool/pool.go`: *"no existe hoy ningún endpoint
  público estable que las sirva"*).

Así que el camino sostenible es **servirlo vos**: tus cuentas, tu endpoint, un
solo lugar donde rotar.

## La pieza: `GET /pool` del Worker

No hay un archivo nuevo que desplegar; el endpoint vive en el Worker que ya
existe para las claves:

```
deeplinks/proxy-qobuz/worker.js   ← ya trae la ruta /pool
```

```
GET /pool  →  200 text/plain
              user_auth_token=<token de la cuenta 1>
              user_auth_token=<token de la cuenta 2>
```

El formato **no es decorativo**: la app baja esta URL y saca las credenciales con
`sessionpool.ExtraerCredencialesQobuz`, que reconoce pares `clave=valor`
(`user_auth_token=...`, `token=...`, `arl=...`). **Si sirvieras los tokens sueltos,
uno por línea sin la clave, el pool quedaría vacío en silencio** — esto está
cubierto por `TestExtraerCredencialesQobuzLeeElFormatoDelPoolDelWorker`.

## Levantarla

No hace falta Docker: es un Worker de Cloudflare (una función).

```bash
# 1) publicá el Worker (panel de Cloudflare o wrangler)
#    archivo: deeplinks/proxy-qobuz/worker.js
# 2) cargá las variables (ver .env.example):
#    QOBUZ_APP_ID, QOBUZ_APP_SECRET  y  QOBUZ_AUTH_TOKENS
wrangler secret put QOBUZ_APP_SECRET
wrangler secret put QOBUZ_AUTH_TOKENS
```

`QOBUZ_AUTH_TOKENS` es el punto entero del endpoint: **tu** pool de sesiones de
Qobuz, una por cuenta, separadas por coma. Sin tokens vivos, `/pool` responde
`503` (con la palabra `token`, que la app lee para pausar la fuente con backoff en
vez de pagar la espera en cada arranque).

### El pool NO tiene que ser público

Por defecto `/pool` es una URL abierta: quien la tenga ve tus tokens. Para
cerrarlo, configurá `QOBUZ_POOL_SECRET` y pasá el secreto **en la ruta**:

```bash
wrangler secret put QOBUZ_POOL_SECRET   # p.ej. un uuid
curl -s https://qobuz-proxy.guttural-engineer.workers.dev/pool/<secreto>
```

Con eso, `/pool` sin el secreto (o con uno equivocado) responde `403`, y la app
tiene que apuntarle a la ruta con el secreto:

```
qobuzPoolUrls  →  https://qobuz-proxy.guttural-engineer.workers.dev/pool/<secreto>
```

El secreto va por RUTA (o `?s=`) y no por cabecera **a propósito**: el bajador de
fuentes de la app (`sessionpool.DescargarFuente`) no manda cabeceras propias, así
que una URL con el secreto es la única forma de autenticar sin cambiar el bajador.

## Conectarla a Bitly

Ya está conectada: la app trae un **origen de fábrica** para `qobuzPoolUrls`
(`go_backend/internal/sessionpool/qobuz.go`,
`QobuzPoolURLsPorDefecto`), y es lo que se usa **siempre al arrancar** cuando el
usuario no configuró ninguna URL.

| Pieza | Estado |
|---|---|
| `sessionpool.QobuzPoolURLsPorDefecto` | `https://qobuz-proxy.guttural-engineer.workers.dev/pool/<secreto>` (tu Worker; cambialo si desplegás en otro) |
| `qobuzPoolUrls` (Ajustes) | vacío = se usa el de fábrica; con una URL tuya, **reemplaza** al default (así también se apaga) |
| `QOBUZ_POOL_SECRET` (Worker) | si lo configurás, la URL tiene que llevar el secreto: `.../pool/<secreto>` |
| Push de arranque | `ConfigProveedor.empujarSiempre` de `qobuz-web` empuja los ajustes aunque estén vacíos, que es lo que dispara el pool |

Para **apagar** el origen de fábrica, poné cualquier URL propia en
`qobuzPoolUrls` (no se suman: la tuya manda).

## Verificarla

```bash
# 1) ¿publica el pool? (una línea por cuenta)
curl -s https://qobuz-proxy.guttural-engineer.workers.dev/pool/<secreto>

# 2) ¿el backend lo lee? (corre el test del contrato, sin red)
cd go_backend && go test ./internal/gobackend -run QobuzPool -count=1 -v

# 3) ¿el Worker está sano? (offline, sin desplegar)
node deeplinks/proxy-qobuz/verificar.mjs
```

## Notas honestas

- **Esto no crea cuentas.** Cada token es la sesión de una cuenta **con
  suscripción**; sin plan, Qobuz degrada el audio a MP3 320. Automatizar el alta
  no es posible: Qobuz no tiene endpoint para eso (y sus términos lo prohíben).
- **Un pool caído no rompe nada.** Una fuente que falla se cuenta como caída y
  se sigue; el canal **Qobuz firmado** (claves públicas) y **Soulseek** funcionan
  igual sin este endpoint.
- **Es una URL pública por defecto.** Configurá `QOBUZ_POOL_SECRET` y apuntá
  `qobuzPoolUrls` a `/pool/<secreto>`; sin eso, quien tenga el link ve tus tokens.
  (La app no manda cabeceras al bajar fuentes de pool, por eso el secreto va en la
  ruta y no en un `Authorization`.)
- **Es `no-store` a propósito**: si rotás un token, la próxima bajada del pool ya
  lo ve, sin esperar caché.
