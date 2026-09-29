# Códigos premium: firma local + registro en el Worker

Los códigos se validan **en el teléfono** (funciona sin internet y sin que nada
esté encendido) y el **registro** (confirmar que el código existe y marcarlo como
usado) lo hace un **Worker tuyo**, que guarda la llave de GitHub en su entorno.

Eso reemplaza al diseño viejo, donde la app llevaba **compilado** un PAT de GitHub
para leer/escribir `codes.json`: los binarios se publican en un repo público, así
que cualquiera sacaba ese token del APK con `unzip` + `grep` (y era un token
clásico: acceso a **todos** los repos de la cuenta). Además, los formatos viejos
validan con un secreto HMAC que también viaja en el binario → con eso cualquiera
podía **fabricar** códigos válidos.

## Los tres formatos (el viejo se queda, a propósito)

| Formato | Ejemplo | Cómo valida | ¿Se puede falsificar? |
|---|---|---|---|
| **Firmado** (nuevo) | `BITLY2.<payload>.<firma>` | Ed25519 con la clave **pública** embebida | **No**: firmar requiere la clave privada, que nunca sale de tu máquina |
| Legacy de la app | `dataB64.sigB64` | HMAC con `bitly_secret_key_v1` (dentro del binario) | Sí (mientras el formato siga aceptándose) |
| Legacy `BITLY-…` | `BITLY-pablo-A1B2C3` | HMAC con `bitly-premium-secret-2026` (dentro del binario) | Sí (ídem) |

Los dos legacy se mantienen **sin cambios** para que los códigos ya repartidos
sigan funcionando. Cuando quieras cerrar esa puerta del todo, hay que dejar de
aceptarlos (y avisar con tiempo a quien los tenga).

## Emitir un código

```bash
# 1) Una sola vez: el par de claves (scripts/keys/ está en .gitignore)
python scripts/release/generar_claves.py
#    → y pegá la clave pública que imprime en
#      go_backend/internal/premium/firmados.go (const clavePublicaFirmados)

# 2) Cada venta / entrega
python scripts/release/generar_codigo.py --dias 365 --tier premium --id pedido-123
#    → BITLY2.… (una línea: eso es lo que le pasás al cliente)

# 3) Soporte: revisar un código sin app de por medio
python scripts/release/generar_codigo.py --verificar BITLY2.…
```

El `--id` sirve para encontrarlo después en el registro. La expiración va firmada
dentro del código: un código vencido no valida aunque alguien lo edite (cambiar
el payload invalida la firma).

## El registro (tu Worker)

Rutas (`PREMIUM_SECRET` va en la ruta, la app no manda cabeceras):

```bash
npx wrangler secret put GITHUB_TOKEN      # Contents: RW SOLO sobre bitly_codes_premium (+ Issues: write si querés reportes)
npx wrangler secret put PREMIUM_SECRET
npx wrangler deploy
```

| Ruta | Qué hace |
|---|---|
| `POST /premium/<secreto>/verificar` | devuelve el estado del código (`activo`, `usado`, `cancelado`, `libre`, `no_encontrado`) |
| `POST /premium/<secreto>/usar` | lo marca como usado (y **anota** los firmados que no estaban, previa verificación de la firma) |
| `POST /premium/<secreto>/reporte` | crea el issue de un reporte de la app |

Y el build inyecta la URL (mismo mecanismo que el Worker de Qobuz):

```bash
PREMIUM_REGISTRO_URL=https://<worker>/premium/<secreto>   # en qobuz-worker.env
source scripts/dev/qobuz_inyeccion.sh                     # exporta QOBUZ_LDFLAGS
```

## Qué pasa si el Worker no está

| Situación | Qué pasa |
|---|---|
| El Worker no responde | El código **se activa igual** (la firma se verificó local) y el "marcar usado" queda **pendiente** en `usados-pendientes.json`; se reintenta al arrancar la app |
| El registro dice `usado` / `cancelado` | Se **bloquea** (es lo que impide reusar un código) |
| Un código firmado no está anotado | Se acepta y se anota solo (la firma prueba que salió de tu clave privada) |
| Un código legacy no está anotado | Se rechaza (`codigo_no_encontrado`), como siempre |
| No hay `PREMIUM_REGISTRO_URL` inyectada | El registro no se consulta: se valida solo la firma (igual que antes de tener token) |

## Pruebas

```bash
cd go_backend && go test ./internal/premium/ -count=1     # firma, formatos viejos y registro
node scripts/pruebas/premium_worker.mjs                   # rutas del Worker con GitHub simulado
```
