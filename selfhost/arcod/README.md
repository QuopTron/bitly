# Instancia propia de arcod (self-host mínimo)

Estos archivos **no son de Bitly**: son un parche para tu **fork de `arcod`**.
Resuelven la única pieza que el repo abierto no trae — la ruta que entrega el
audio — y dejan la instancia levantable con un comando.

## Por qué hace falta una ruta extra

Medido contra el repo público (`fufu-noir/arcod`, MIT):

| Ruta | ¿Está en el repo? | Qué hace |
|---|---|---|
| `app/api/get-music` | sí | busca el ISRC en el catálogo |
| `app/api/v2/guest/rate-limit` | sí | publica el presupuesto por IP |
| `app/api/player/stream/<id>` | **no** | entrega el enlace del FLAC |
| `server/src/routes/stream.ts` (`/v2/stream`) | sí | pero está detrás de sesión |

O sea: sin este archivo, una instancia propia **busca pero no suena**.

## Qué poner y dónde

```
tu-fork-de-arcod/
├── app/api/player/stream/[id]/route.ts   ← nuevo (la ruta que faltaba)
├── Dockerfile                            ← nuevo
├── docker-compose.yml                    ← nuevo
└── .env.example                          ← nuevo (copialo a .env)
```

El único archivo que va **dentro** del árbol de Next es la ruta; los otros tres
van en la raíz, al lado de `package.json`.

## Contrato de la ruta

```
GET /api/player/stream/<id>?quality=<5|6|7|27>
→ 200 { "url": "https://…", "mimeType": "audio/flac", "quality": 6, "trackId": 312055179 }

403  sesión requerida cuando la calidad supera STREAM_GUEST_QUALITY
400  id o calidad inválidos
503  { "error": "No healthy Qobuz tokens available (…)" } — el pool quedó vacío
```

Dos detalles que importan para que la app se comporte bien:

- **La palabra `token` en el error 503 es a propósito.** Bitly lo lee y pone la
  fuente en pausa con backoff (5 → 10 → 20 → 40 → 60 min) en vez de pagar la
  espera en cada canción. Si cambiás ese texto, perdés ese alivio.
- **`mimeType` se deriva del format id** porque `getDownloadURL` devuelve solo
  la URL de Qobuz. Un pedido sin pérdida que llegue en `audio/mpeg` se rechaza
  en la app: no se degrada la calidad a escondidas.

## Levantarla

```bash
cp .env.example .env
# completá QOBUZ_APP_ID, QOBUZ_SECRET y QOBUZ_AUTH_TOKENS
docker compose up -d --build
```

`QOBUZ_AUTH_TOKENS` es el punto entero de la instancia: es **tu** pool de
sesiones de Qobuz (una por cuenta, separadas por coma). Sin tokens vivos, la
API responde el 503 de arriba y no hay canción que se resuelva.

No hacen falta Cloudflare R2, el Lambda ni el worker: esos existen para
**descargar en la nube**, y Bitly ya baja el audio por su cuenta.

## Verificarla

```bash
# 1) ¿está viva?
curl -s http://localhost:3000/api/v2/guest/rate-limit

# 2) ¿suena? (misámoslo con el enlace de una canción)
curl -s "http://localhost:3000/api/player/stream/312055179?quality=6"
# → {"url":"https://…","mimeType":"audio/flac","quality":6,"trackId":312055179}

# 3) ¿de verdad entrega FLAC y acepta Range?
curl -sI "$(curl -s "http://localhost:3000/api/player/stream/312055179?quality=6" | sed -E 's/.*"url":"([^"]+)".*/\1/')" | grep -i "content-type\|accept-ranges"
# → content-type: audio/flac    accept-ranges: bytes
```

## Conectarla a Bitly

Ajustes → Credenciales → Rescate de audio:

| Campo | Valor |
|---|---|
| `arcod` | la URL de tu instancia, ej. `http://192.168.1.50:3000` |
| `arcod_token` | vacío si la instancia es abierta; el JWT de sesión si pusiste `STREAM_GUEST_QUALITY=5` |

Bitly prueba tres puertas de stream en orden y **recuerda la que funciona**
(`/api/player/stream/` → `/v2/stream/` → `/api/get-track-url`), así que no hay
que decirle cuál usa tu instancia. Si cambiás la URL, la memoria se borra sola.

## Notas honestas

- **Esto no vuelve más estable al catálogo de un tercero**: tu instancia vive de
  *tus* cuentas de Qobuz. Si querés FLAC sin depender de nada, el canal **Qobuz
  firmado** de Bitly (que va primero y usa tu propia sesión) es el camino corto.
- **Por LAN funciona con `http://`**: el cliente del rescate está en Go, no en la
  capa de Android, así que la política de tráfico claro no lo frena. Para
  exponerla a internet, usá el `caddy` comentado en el compose.
- **La web completa** (login, panel de admin, descargas en la nube) necesita el
  resto del `.env.example` del repo. Para lo que Bitly usa, alcanza con las
  cuatro claves de Qobuz.
