# Fuente Tidal propia (hifi-api)

Guía para levantar **tu** instancia de [`binimum/hifi-api`](https://github.com/binimum/hifi-api)
y dejar de depender de las APIs públicas de terceros. Es el equivalente de
`selfhost/arcod/` para el canal **`tidal-hifi`** de la app.

## Por qué existe

El canal `tidal-hifi` habla el contrato de hifi-api y hoy usa dos bases de
fábrica más una **lista viva** que publica un health-check
(`proxy.odskyler.workers.dev/health`). Medido el 2026-09-30: el health-check
responde, pero las cuentas Tidal de esos proxies están suspendidas por abuso
(`abuse_detected: User account is suspended due to abuse`). Tidal está baneando
cuentas en masa a todo el mundo que use estas APIs, **incluidos los que las
tienen en su casa**. La única versión que no depende de la cuenta de un tercero
es la tuya.

> Ojo con la expectativa: esto **no** arregla el canal `espejos`. Ese contrato
> (`/track/?isrc=`) es Deezer con ARLs, otra cosa. Ver
> [`docs/canales_rescate_alternativas.md`](../../docs/canales_rescate_alternativas.md).

## Regla que evita que te baneen

hifi-api trae una **cola**: cada cuenta de reproducción atiende UNA petición en
vuelo a la vez, y si todas están ocupadas contesta `202 Accepted` con
`Retry-After` para que el cliente espere. Respetala (no pidas en paralelo) y la
cuenta dura. La propia doc de hifi-api lo dice: *"sending one request for a track
at a time from one IP at a time"* es lo que baja el riesgo a casi cero.

## Levantarla

1. Cloná el proyecto acá adentro:

   ```bash
   git clone https://github.com/binimum/hifi-api selfhost/hifi-api/app
   ```

   **Fijá un commit** antes de confiar en él (`git -C app checkout <commit>`): es
   un repo que se mueve y un `main` inesperado puede cambiar el contrato.

2. Generá `token.json` en tu máquina (es interactivo, por eso no vive en la
   imagen). El script vive en `tidal_auth/`:

   ```bash
   cd app/tidal_auth
   pip install -r requirements.txt
   python tidal_auth.py          # sigue las instrucciones
   # deja token.json en app/
   ```

   Podés poner varias cuentas: una es `role: catalog` (solo metadata, no necesita
   suscripción) y las demás de reproducción. Con dos cuentas de reproducción, dos
   peticiones concurrentes, una por cuenta.

3. Copiá el entorno y levantá:

   ```bash
   cp .env.example .env
   # ajustá lo que haga falta (normalmente nada)
   docker compose up -d
   ```

4. Verificá:

   ```bash
   curl -s http://localhost:8000/          # {"version":"2.x","Repo":...}
   curl -s http://localhost:8000/info/?id=144371283
   ```

## Conectarla a la app (honestidad sobre el cableado)

El canal `tidal-hifi` tiene su lista de bases en el código
(`go_backend/internal/provider/tidalhifi/client.go`, `basesDeFabrica`) y suma las
que publique el health-check. **Hoy no hay un ajuste de Ajustes para pegar la
URL**, así que para que la app use la tuya hay dos caminos:

- **Compilar con tu URL** (rápido, una línea): cambiá `basesDeFabrica` por tu
  `http://<host>:8000` y recompilá. Es lo que hace un build propio.
- **Publicarla en tu propio health-check**: el contrato que consume la app es un
  JSON `{"active":[{"url":"…","status":200}]}`. Si servís ese JSON, apuntá
  `saludProxy` (en `tidalhifi/salud.go`) a tu URL y tu instancia entra sola,
  junto con las que estén vivas.

No hay pasos con secretos en el binario: tu `token.json` vive **solo** en tu
instancia.

## Cuándo NO conviene

- Si no querés administrar una cuenta Tidal ni un servidor, **dejá `tidal-hifi` y
  el relay como están**: el rescate ya funciona. Esta guía es para quien quiera
  una fuente que no dependa de terceros.
- Para el catálogo libre (clásico, conciertos, CC) no hace falta nada de esto:
  ya lo cubren Internet Archive / Jamendo / Wikimedia (ver
  `docs/repositorios_lossless.md`).
