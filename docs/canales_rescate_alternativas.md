# Canales del rescate: estado real y cómo reparar los 3 caídos

Medido el **2026-09-30** con peticiones reales (no con documentación). El
diagnóstico del log de la app marcaba tres canales en rojo:

```
qobuz-firmado │ ⛔ a medio camino      │ un user_auth_token real
arcod         │ ⛔ muerto en el origen │ tu instancia propia (selfhost/arcod)
espejos       │ ⛔ ARLs baneados       │ otro espejo vivo en mirrors
```

Esta nota dice **por qué** están así y cuál es la salida que no vuelve a caerse.

## Lo que está vivo y lo que no (probado)

| Servicio | Estado | Evidencia |
|---|---|---|
| `dzr.tabs-vs-spaces.wtf` (espejo por defecto) | **up, pool muerto** | `/track/?isrc=…` → `{"error":"All Deezer accounts are dead (banned/expired ARLs)"}` |
| `arcod.xyz` | **up, sin tokens** | `arcod: 500 No healthy Qobuz tokens available` |
| `flacdownloader.com/api/qobuz/keys` | **vivo** | es el origen de claves por defecto del canal firmado |
| `proxy.odskyler.workers.dev/health` | **vivo** | `active`: `media-proxy.odskyler.com`, `tidal-proxy.147-93-168-21.sslip.io` |
| `hifi.rhythmax.workers.dev` / `hifi.rtmx.workers.dev` | **up, cuenta suspendida** | `/tracks?q=` → `abuse_detected: User account is suspended due to abuse` |
| `superflac.com` (canal `sitios`) | **vivo** | HTTP 200 |
| `stash-tipjar.rawnaldclark.workers.dev/lossless.json` | **vivo** | el `stash-relay` que ya entrega FLAC en ~300 ms |
| `api.monochrome.tf` y `*-1.monochrome.tf` (INSTANCES.md de Monochrome) | **no existen** | NXDOMAIN (Cloudflare sin registro A) |
| `*.qqdl.site` | no alcanzable desde esta red | handshake TLS fallido |
| pools públicos de `user_auth_token` de Qobuz | **no existen** | — |

**Conclusión dura:** los tres canales viven de *pools de cuentas pagas compartidas*,
y los tres servicios los están baneando en masa (ARLs de Deezer muertos, cuentas
Tidal `abuse_detected`, tokens Qobuz vacíos). Cualquier "espejo/token público"
que se pegue va a morir igual. Lo único durable es **cuenta propia + self-host**,
o **catálogos sin credenciales** (que la app ya usa).

Y una verdad que importa para no romper nada: la app **ya funciona** con los tres
caídos. El log muestra `stash-relay` devolviendo FLAC de Qobuz en ~300 ms, y
`sitios` + `tidal-hifi` + Internet Archive como respaldos. Los tres canales rotos
son *opcionales*.

## 1) `qobuz-firmado` — "a medio camino"

**Causa:** el canal firma con las claves públicas de Qobuz, pero sin un
`user_auth_token` de una cuenta **con suscripción** Qobuz entrega una **muestra de
30 s** (o MP3 320). No hay pool público legítimo; es una condición de cuenta.

**Solución (una sola vez, para todos los usuarios):** poné tu token en el Worker
propio. El relay ya lo reenvía por cabecera `X-User-Auth-Token`, así que no hay
que pegar nada en cada teléfono:

```bash
cd deeplinks/proxy-qobuz
npx wrangler secret put QOBUZ_USER_TOKEN   # sesión de una cuenta con suscripción
npx wrangler deploy
```

El token sale del web player de Qobuz: login en `qobuz.com` → F12 → Application →
Local Storage → `user_auth_token`. (La extensión `qobuz-web` también puede emitirlo
con email+password.) Alternativa por-telefono: Ajustes → Credenciales →
`qobuz_user_token`.

Ruta barata y legítima: plan **Dúo** (2 cuentas) o **Familia** (hasta 6). El
diagnóstico de la app (`probarCanal`) distingue `token_invalido` de
`sin_suscripcion`, así que dice cuál de las dos cosas arreglar.

## 2) `arcod` — "muerto en el origen"

**Causa:** `arcod.xyz` es **una** instancia de un tercero; su pool de tokens de
Qobuz quedó vacío (`No healthy Qobuz tokens available`). No hay otra instancia
pública: es un proyecto único. Va a seguir vacío.

**Solución A — self-host (recomendada):** `selfhost/arcod/` ya trae la ruta que
falta (`/api/player/stream/[id]`), el `Dockerfile` y el `docker-compose.yml`:

```bash
cd selfhost/arcod
cp .env.example .env
# QOBUZ_APP_ID, QOBUZ_SECRET y QOBUZ_AUTH_TOKENS (las sesiones de TUS cuentas)
docker compose up -d --build
```

Luego poné la URL en el ajuste `arcod` (o en el switch "Canal arcod" de Ajustes →
Descargas → Rescate sin pérdida). El mismo token del punto 1 sirve acá.

**Solución B — apagarlo:** con `qobuz-firmado` teniendo token, arcod es
redundante (los dos leen el catálogo de Qobuz). Apagalo y te ahorra su
presupuesto. Ya se puede: switch "Canal arcod", o `arcod=off`.

## 3) `espejos` — "ARLs baneados"

**Causa:** el contrato de los espejos (`/track/?isrc=`) es Deezer con **ARLs**. Deezer
los está baneando en masa y Deemix está muerto, así que todo espejo público
basado en ARLs muere igual. **No hay espejo Deezer vivo que valga la pena pegar.**

**Solución — cambiar de vía, no de espejo:**

- Apagá el canal (switch "Espejos por ISRC", o `mirrors=off`). No se le hace ni
  una petición.
- Dejá que hagan el sin pérdida los canales que **no** dependen de ARLs:
  `sitios` (superflac y otras instancias del mismo software), `stash-relay`
  (vivo), `tidal-hifi` (con health-check y failover) y los catálogos libres
  (Internet Archive / Jamendo / Wikimedia, ver `repositorios_lossless.md`).
- Si querés un espejo **tuyo**: ver `selfhost/hifi-api/` (fuente Tidal) — pero es
  solo para tu cuenta y con cola de 1 petición a la vez, porque Tidal también
  suspende cuentas por abuso.

## Lo que la app ahora trae para esto

| Pieza | Dónde | Qué hace |
|---|---|---|
| `mirrors=off` (y volver a encender) | `flacrescue/client.go` | Apaga el canal de espejos sin borrar la config; `""` restaura los de fábrica |
| Switch "Espejos por ISRC" | Ajustes → Descargas → Rescate sin pérdida | Lo anterior, sin editar nada a mano |
| Switch "Canal arcod" | ídem | Apaga/enciende `arcod` |
| Botón **Comprobar canales** | ídem | Informe barato (sin red) del estado de los 5 canales: `ok / apagado / sin_configurar / sin_cuentas / pausado / sin_sesion` |
| Acción `probarCanales` | `flacrescue/canales_diagnostico.go` | Lo mismo, por el contrato de acciones (`{ok, result:{canales, agotado, detalle}}`) |

Nada de esto toca la ruta rápida: `stash-relay`, `sitios` y `tidal-hifi` siguen
igual, y apagar un canal solo le quita peticiones muertas a la carrera.
