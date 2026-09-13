#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# pot_local.sh — levanta el proveedor de PO Token (bgutil) en ESTA máquina,
# sin docker, para que YouTube no pida "confirmá que no sos un bot".
#
# POR QUÉ
# Las IPs marcadas (emulador, datacenter, VPN) reciben el check de bot en todos
# los clientes InnerTube de YouTube. La salida sin cuenta es un proveedor de PO
# Token; la extensión ytmusic-spotiflac ya sabe hablarle (ajuste poTokenMode =
# "auto" + los candidatos locales en el puerto 4416), así que acá solo hay que
# tener el server corriendo.
#
# DOCKER NO HACE FALTA
# El server es un programa Node. El repo oficial también publica una imagen,
# pero el camino nativo evita instalar Docker. Requisitos: Node >= 20 y git.
#
# SEGURIDAD
# El server es SIN AUTENTICACIÓN y puede generar tokens (y ejecutar JavaScript
# del BotGuard). Por eso se levanta con el bind por defecto, que es SOLO
# loopback (127.0.0.1 / ::1): no queda expuesto a la red local ni a internet.
# No le pases -H 0.0.0.0.
#
# CÓMO LLEGA LA APP
#   - App de escritorio (Windows/macOS/Linux): mismo equipo -> 127.0.0.1:4416.
#   - Emulador de Android: adentro del emulador 127.0.0.1 es el emulador, no el
#     PC. Dos caminos, los dos ya contemplados por la extensión:
#       a) `adb reverse tcp:4416 tcp:4416`  -> el 127.0.0.1:4416 del emulador
#          es el 4416 del PC (es el que funciona siempre; es lo que se usa acá).
#       b) el candidato http://10.0.2.2:4416 (alias del loopback del host).
#
# Uso (desde la raíz del repo, en Git Bash):
#   scripts/pruebas/pot_local.sh                 # clona (si hace falta), compila y levanta
#   POT_DIR=/otra/ruta scripts/pruebas/pot_local.sh
#   scripts/pruebas/pot_local.sh --estado        # ¿está respondiendo en 4416?
# ─────────────────────────────────────────────────────────────

set -uo pipefail

RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"

# El proveedor NO es parte del proyecto y no debe vivir adentro del repo, así que
# el default se busca AL LADO del repo: `.../bgutil-ytdlp-pot-provider` junto a
# `.../proyectos/bitly/` (o sea en el abuelo del repo). Se prueban unos cuantos
# candidatos razonables y gana el primero que exista; siempre se puede forzar
# con POT_DIR=/ruta/x scripts/pruebas/pot_local.sh
buscar_pot_dir() {
  local cand
  for cand in \
    "${POT_DIR:-}" \
    "$(dirname "$(dirname "$RAIZ")")/bgutil-ytdlp-pot-provider" \
    "$HOME/bgutil-ytdlp-pot-provider" \
    "$(dirname "$RAIZ")/bgutil-ytdlp-pot-provider"; do
    # Alcanza con que esté CLONADO (package.json); si falta compilar, el paso de
    # abajo lo hace. Buscar solo el build haría que un clon sin compilar
    # pareciera "no encontrado" y el mensaje mandaría a clonar de nuevo.
    [ -n "$cand" ] && [ -f "$cand/server/package.json" ] && { printf '%s\n' "$cand"; return 0; }
  done
  # Ninguno compilado: devolvemos el candidato principal para que el mensaje de
  # error diga dónde se esperaba.
  printf '%s\n' "${POT_DIR:-$(dirname "$(dirname "$RAIZ")")/bgutil-ytdlp-pot-provider}"
}

POT_DIR="$(buscar_pot_dir)"

estado() {
  local code
  code="$(curl -s -m 5 -o /dev/null -w '%{http_code}' http://127.0.0.1:4416/ 2>/dev/null || true)"
  if [ "$code" = "400" ]; then
    echo "proveedor RESPONDIENDO en 127.0.0.1:4416 (HTTP 400 en / es lo esperado)"
    return 0
  fi
  echo "proveedor NO responde en 127.0.0.1:4416 (code='${code:-sin respuesta}')"
  return 1
}

if [ "${1:-}" = "--estado" ]; then
  estado
  exit $?
fi

if [ ! -f "$POT_DIR/server/package.json" ]; then
  echo "No encontré el proveedor en: $POT_DIR"
  echo
  echo "Clonalo una vez (fuera del repo) con:"
  echo "  git clone --single-branch --branch 2.0.0 --depth 1 \\"
  echo "    https://github.com/Brainicism/bgutil-ytdlp-pot-provider.git \"$POT_DIR\""
  echo
  echo "Si ya está clonado pero sin compilar, este script lo compila solo"
  echo "(npm ci + tsc). Si está en otra ruta:"
  echo "  POT_DIR=/ruta scripts/pruebas/pot_local.sh"
  exit 2
fi

cd "$POT_DIR/server"

if [ ! -f build/main.js ]; then
  echo "==> Compilando el proveedor (primera vez): npm ci + tsc"
  npm ci || exit 1
  npx tsc || exit 1
fi

if estado >/dev/null 2>&1; then
  echo "==> Ya hay un proveedor corriendo en 4416; no levanto otro."
  echo
  echo "Para el emulador de Android, además:  adb reverse tcp:4416 tcp:4416"
  exit 0
fi

echo "==> Levantando el proveedor (bind loopback, sin docker)"
node build/main.js
