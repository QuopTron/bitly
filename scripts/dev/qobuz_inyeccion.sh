#!/usr/bin/env bash
#
# qobuz_inyeccion.sh — Arma el `-ldflags` que INYECTA la config del Worker de
# Qobuz (pool, /keys y api base) sin escribirla en el fuente.
#
# Por qué existe: la URL del Worker lleva su secreto en la ruta (`/pool/<secreto>`
# y `/<secreto-relay>/keys`). Si esa URL se escribe en el repo —que es público—
# cualquiera la lee, firma con tus claves y quema tu cuota diaria. En vez de eso,
# los valores viven en `qobuz-worker.env` (raíz, GITIGNOREADO) o en variables de
# entorno con los mismos nombres, y el build los inyecta con -ldflags. Un build
# sin inyección queda con los defaults PÚBLICOS: canal firmado directo a Qobuz y
# sin pool de fábrica.
#
# Uso:
#   source scripts/dev/qobuz_inyeccion.sh          # exporta QOBUZ_LDFLAGS
#   bash   scripts/dev/qobuz_inyeccion.sh --gomobile   # imprime el comando listo
#
# Variables (todas opcionales; las que falten simplemente no se inyectan):
#   QOBUZ_POOL_URL   https://<worker>/pool/<secreto>
#   QOBUZ_KEYS_URL   https://<worker>/<secreto-relay>/keys
#   QOBUZ_API_BASE   https://<worker>/<secreto-relay>/api.json/0.2
#
# Parte del flujo: build (empaquetar el backend Go con tu Worker).

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)"
ARCHIVO="$RAIZ/qobuz-worker.env"
MODULO="github.com/zarz/bitly/go_backend"

# El archivo es opcional; las variables de entorno ya seteadas mandan.
if [ -f "$ARCHIVO" ]; then
  for clave in QOBUZ_POOL_URL QOBUZ_KEYS_URL QOBUZ_API_BASE; do
    if [ -z "$(printenv "$clave" 2>/dev/null || true)" ]; then
      valor="$(grep -E "^${clave}=" "$ARCHIVO" | tail -1 | cut -d= -f2- | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      if [ -n "$valor" ]; then
        export "$clave=$valor"
      fi
    fi
  done
fi

QOBUZ_LDFLAGS="-s -w"
if [ -n "${QOBUZ_POOL_URL:-}" ]; then
  QOBUZ_LDFLAGS="$QOBUZ_LDFLAGS -X $MODULO/internal/sessionpool.QobuzPoolURLInyectada=$QOBUZ_POOL_URL"
fi
if [ -n "${QOBUZ_KEYS_URL:-}" ]; then
  QOBUZ_LDFLAGS="$QOBUZ_LDFLAGS -X $MODULO/internal/provider/flacrescue.QobuzKeysURLInyectada=$QOBUZ_KEYS_URL"
fi
if [ -n "${QOBUZ_API_BASE:-}" ]; then
  QOBUZ_LDFLAGS="$QOBUZ_LDFLAGS -X $MODULO/internal/provider/flacrescue.QobuzAPIBaseInyectada=$QOBUZ_API_BASE"
fi

export QOBUZ_LDFLAGS

# Con --gomobile se imprime el comando de build ya armado (y no se exporta nada
# raro). Es el que se usa para el AAR de Android.
if [ "${1:-}" = "--gomobile" ]; then
  echo "cd go_backend && gomobile bind -target=android -androidapi 24 -ldflags=\"\$QOBUZ_LDFLAGS\" -o ../build/bitly-backend.aar ."
  echo "# (QOBUZ_LDFLAGS ya está exportado en ESTA shell)"
fi
