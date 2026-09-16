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
| `GET /keys` | devuelve `{appId, appSecret}` (con caché de 5 min) |
| `GET /api.json/0.2/*` | reenvía **firmado** a Qobuz, agregando `app_id`, `request_ts` y `request_sig` |

Con esto:

- las claves y el `QOBUZ_USER_TOKEN` (si tenés suscripción, para FLAC real) **viven
  en tu Worker**, nunca en el teléfono de los usuarios;
- el tráfico de tus usuarios va a **tu dominio**; Qobuz ve tu Worker, no a cada
  usuario;
- si el secreto rota, se arregla en **un solo lugar**: la app se repara sola (pide
  claves nuevas cuando Qobuz contesta 401) sin que nadie actualice nada.

## Despliegue

1. Pegá `worker.js` en el panel de Cloudflare Workers (o `wrangler deploy`).
2. Variables del Worker:
   - `QOBUZ_APP_ID` (texto)
   - `QOBUZ_APP_SECRET` (secret)
   - `QOBUZ_USER_TOKEN` (opcional, secret — con cuenta con suscripción: FLAC real)
3. En la app: **Ajustes → Credenciales → Rescate de audio**
   - *Origen de claves Qobuz*: `https://TU-WORKER.workers.dev/keys`
   - opcional, para que también la API pase por tu Worker:
     `qobuz_api_base` = `https://TU-WORKER.workers.dev/api.json/0.2`

## Verificación (offline, sin desplegar)

```bash
node deeplinks/proxy-qobuz/verificar.mjs
```

Comprueba el MD5 hecho a mano contra vectores de `hashlib` (python), que la firma
coincida **con el mismo vector que el backend Go**, el contrato de `/keys` y que el
relay agrega la firma sin dejar salir el `app_secret`.

> Este Worker es **opcional**: sin configurar nada, el canal Qobuz queda apagado y
> la app sigue igual que siempre (espejos + YouTube).
