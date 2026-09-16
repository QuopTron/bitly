#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# pruebas_extensiones.sh — corre TODOS los verificadores de extensiones.
#
# POR QUÉ EXISTE
# Las extensiones son JavaScript que corre dentro de un sandbox goja en Go. Sus
# bugs son silenciosos: la app no crashea, simplemente "esa fuente no encuentra
# audio" o "tarda muchísimo", y desde afuera parece un problema de red. Estos
# harnesses cargan la extensión REAL en un sandbox tipo goja (con `http`, `log`,
# `utils` y `registerExtension` falsos) y verifican el comportamiento exacto que
# se rompió alguna vez:
#
#   soundcloud_401   → un 401 no debe terminar en `client_id=null` ni en una
#                      tormenta de reintentos; debe fallar con "HTTP 401" para
#                      que el cooldown de Go enfríe la fuente.
#   deezer_pool      → rotación del pool de ARLs (orden, rotación, fallo claro).
#   tidal_qobuz_pool → rotación del pool de tokens/cuentas de Tidal y Qobuz.
#   ytmusic_pot      → el proveedor de PO Token (bgutil) que evita el "confirmá
#                      que no sos un bot" de YouTube.
#   resolve_enlaces  → URL compartida/pegada -> ítem reproducible, con los
#                      enlaces REALES de Spotify y YouTube (incluidos los ?si=
#                      y ?feature=shared que antes no resolvían) y el resto de
#                      las fuentes: Deezer, Tidal, Qobuz, Amazon y Apple.
#
# Nada de esto toca la red: son deterministas, así que sirven en CI.
#
# SE CORRE DOS VECES POR EXTENSIÓN
# Contra `assets/extensions/` Y contra `go_backend/internal/bundled_extensions/`.
# La app carga la copia EMBEBIDA, no la de assets: si las dos se desincronizan,
# verificar solo assets daría un verde falso sobre código que el usuario no
# ejecuta. (El test Go `assets_parity_test.go` cubre lo mismo, pero acá el
# resultado se lee junto al del harness y el diagnóstico es inmediato.)
#
# Se conecta con: assets/extensions/, go_backend/internal/bundled_extensions/,
# y los verificadores en scripts/pruebas/extensiones/.
#
# Uso (desde la raíz del repo, en Git Bash):
#   scripts/pruebas/pruebas_extensiones.sh
# ─────────────────────────────────────────────────────────────

set -uo pipefail

RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"
HARNESS="$RAIZ/scripts/pruebas/extensiones"
ASSETS="$RAIZ/assets/extensions"
BUNDLED="$RAIZ/go_backend/internal/bundled_extensions"

if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: no encontré node (hace falta para los verificadores JS)." >&2
  exit 1
fi

FALLOS=0
CORRIDAS=0

# corre <descripcion> <comando...>
corre() {
  local desc="$1"; shift
  CORRIDAS=$((CORRIDAS + 1))
  local salida
  if salida="$("$@" 2>&1)"; then
    # Solo mostramos la última línea (los harnesses ya dan detalle en fallo).
    printf '%-34s %s\n' "$desc" "$(printf '%s' "$salida" | tail -n 1)"
  else
    FALLOS=$((FALLOS + 1))
    echo "── FALLA: $desc"
    printf '%s\n' "$salida" | sed 's/^/     /'
  fi
}

# paridad <extension> — la copia embebida debe ser idéntica a la de assets.
paridad() {
  local ext="$1" f
  for f in index.js manifest.json; do
    [ -f "$ASSETS/$ext/$f" ] || continue
    CORRIDAS=$((CORRIDAS + 1))
    if diff -q "$ASSETS/$ext/$f" "$BUNDLED/$ext/$f" >/dev/null 2>&1; then
      printf '%-34s %s\n' "$ext/$f paridad assets<->bundled" "ok"
    else
      FALLOS=$((FALLOS + 1))
      echo "── FALLA: $ext/$f difiere entre assets/ y bundled_extensions/"
    fi
  done
}

echo "=== Verificadores de extensiones (offline) ==="
echo "node: $(node --version)"
echo

# ── SoundCloud: el 401 no debe reintentar con el id que ya rebotó ──────────
for copia in "assets:$ASSETS" "bundled:$BUNDLED"; do
  nombre="${copia%%:*}"; dir="${copia#*:}"
  corre "soundcloud 401 mismo ($nombre)" \
    node "$HARNESS/soundcloud_401.js" "$dir/soundcloud/index.js" mismo
  corre "soundcloud 401 nuevo ($nombre)" \
    node "$HARNESS/soundcloud_401.js" "$dir/soundcloud/index.js" nuevo
done

# ── Deezer: pool de ARLs ──────────────────────────────────────────────────
for copia in "assets:$ASSETS" "bundled:$BUNDLED"; do
  nombre="${copia%%:*}"; dir="${copia#*:}"
  corre "deezer pool ($nombre)" \
    node "$HARNESS/deezer_pool.js" "$dir/deezer/index.js"
done

# ── Tidal + Qobuz: rotación de credenciales ───────────────────────────────
for copia in "assets:$ASSETS" "bundled:$BUNDLED"; do
  nombre="${copia%%:*}"; dir="${copia#*:}"
  corre "tidal+qobuz pool ($nombre)" \
    node "$HARNESS/tidal_qobuz_pool.js" \
      "$dir/tidal-web/index.js" "$dir/qobuz-web/index.js"
done

# ── YouTube Music: proveedor de PO Token (bgutil) ─────────────────────────
for copia in "assets:$ASSETS" "bundled:$BUNDLED"; do
  nombre="${copia%%:*}"; dir="${copia#*:}"
  corre "ytmusic PO token ($nombre)" \
    node "$HARNESS/ytmusic_pot.js" "$dir/ytmusic-spotiflac/index.js"
  corre "ytmusic clientes ($nombre)" \
    node "$HARNESS/ytmusic_clientes.js" "$dir/ytmusic-spotiflac/index.js"
done

# ── Enlaces compartidos: Spotify + YouTube ────────────────────────────────
for copia in "assets:$ASSETS" "bundled:$BUNDLED"; do
  nombre="${copia%%:*}"; dir="${copia#*:}"
  corre "enlaces de las 7 fuentes ($nombre)" \
    node "$HARNESS/resolve_enlaces.js" \
      "$dir/spotify-web/index.js" "$dir/ytmusic-spotiflac/index.js" \
      "$dir/deezer/index.js" "$dir/tidal-web/index.js" "$dir/qobuz-web/index.js" \
      "$dir/amazon/index.js" "$dir/apple-music/index.js"
done

# Auto-test del harness de enlaces: sin searchParams.has (el bug original del
# polyfill de goja) los casos de YouTube DEBEN fallar. Si acá "pasa", el
# harness dejó de probar lo que dice probar.
CORRIDAS=$((CORRIDAS + 1))
if SIN_SEARCHPARAMS_HAS=1 node "$HARNESS/resolve_enlaces.js" \
     "$ASSETS/spotify-web/index.js" "$ASSETS/ytmusic-spotiflac/index.js" \
     "$ASSETS/deezer/index.js" "$ASSETS/tidal-web/index.js" "$ASSETS/qobuz-web/index.js" \
     "$ASSETS/amazon/index.js" "$ASSETS/apple-music/index.js" >/dev/null 2>&1; then
  FALLOS=$((FALLOS + 1))
  echo "── FALLA: el auto-test de enlaces no detecta la falta de searchParams.has"
else
  printf '%-34s %s\n' "auto-test enlaces (sin searchParams.has)" "ok"
fi

# ── Referencias de la guía del PO Token ───────────────────────────────────
# go_backend/POT_TOKEN_YOUTUBE.md nombra archivos y scripts concretos. Si
# alguien renombra uno, la guía seguiría diciendo "corré esto" y el comando no
# existiría: una doc que manda a un archivo inexistente es peor que no tenerla.
echo
echo "--- referencias de la guía del PO Token ---"
CORRIDAS=$((CORRIDAS + 1))
faltan=""
for ruta in \
  scripts/pruebas/pot_local.sh \
  scripts/pruebas/pruebas_extensiones.sh \
  scripts/pruebas/extensiones/ytmusic_pot.js \
  assets/extensions/ytmusic-spotiflac/index.js \
  assets/extensions/ytmusic-spotiflac/manifest.json \
  go_backend/internal/download/orchestrator_video.go \
  go_backend/internal/streaming/play_package.go \
  go_backend/internal/provider/extension_provider_detail.go \
  go_backend/internal/provider/route_youtube_test.go; do
  [ -e "$RAIZ/$ruta" ] || faltan="$faltan $ruta"
done
if [ -n "$faltan" ]; then
  FALLOS=$((FALLOS + 1))
  echo "── FALLA: la guía del PO Token referencia archivos que no existen:$faltan"
else
  printf '%-34s %s\n' "guía POT -> archivos reales" "ok"
fi

# ── Proxy de Qobuz (opcional): firma MD5 y contrato de /keys ────────────────
# No es una extensión, pero es el mismo tipo de verificador: JS offline que evita
# un fallo silencioso (una firma mal armada que Qobuz rechaza con 401).
corre "proxy Qobuz (firma + /keys)" node "$RAIZ/deeplinks/proxy-qobuz/verificar.mjs"

# ── Paridad de las copias (lo que verifica el harness vs lo que embebe la app) ─
echo
echo "--- paridad assets <-> bundled ---"
for ext in soundcloud deezer tidal-web qobuz-web ytmusic-spotiflac spotify-web amazon apple-music; do
  paridad "$ext"
done

echo
if [ "$FALLOS" -eq 0 ]; then
  echo "TODO OK  ($CORRIDAS comprobaciones)"
  exit 0
fi
echo "$FALLOS de $CORRIDAS comprobaciones FALLARON"
exit 1
