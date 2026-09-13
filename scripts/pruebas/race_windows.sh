#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# race_windows.sh — Tests con el DETECTOR DE CARRERAS, nativo en Windows.
#
# NO usa WSL. `go test -race` necesita cgo, o sea un compilador C, y en esta
# máquina no hay gcc, ni clang, ni carga C++ de Visual Studio. Lo que sí hay es
# zig (se instala con `pip install --user ziglang`), que es autónomo y sirve
# como CC. Este script lo localiza y arma el entorno.
#
# Se conecta con: go_backend/ (el backend Go). No toca lib/ ni assets/.
#
# ── Los DOS obstáculos, ninguno obvio ────────────────────────────────────
#
# 1) SÍMBOLOS QUE FALTAN AL ENLAZAR
#    El runtime del detector (ThreadSanitizer) llama a WaitOnAddress,
#    WakeByAddressSingle y WakeByAddressAll. Viven en la API set
#    `api-ms-win-core-synch-l1-2-0`, y el enlazador de zig no la trae sola:
#        lld-link: error: undefined symbol: WaitOnAddress
#    Solución: pedirla explícitamente. (Sin esto el binario ni se construye.)
#
# 2) SHADOW MEMORY FUERA DEL ESPACIO DE DIRECCIONES
#    Con la base de imagen por defecto de Go/zig (0x140000000), ThreadSanitizer
#    calcula su memoria "shadow" cerca de los 257 TB, fuera del espacio de
#    usuario válido de Windows, y VirtualAlloc falla con error 87:
#        ThreadSanitizer failed to allocate 0x000004110000 bytes
#        at 0x100ef71300000 (error code: 87)
#    Bajando la base a 0x400000 el shadow cae dentro del rango y arranca.
#    Comprobado que NO es cosa de este repo: el mismo fallo aparece en un
#    paquete del stdlib (`go test -race strings`) con la base por defecto.
#
# Uso (desde la raíz del repo, en Git Bash):
#   scripts/race_windows.sh                            # todo el backend
#   scripts/race_windows.sh ./internal/streaming/...   # un paquete
#
# Última corrida verificada: 2026-09-12 — suite completa, 33 paquetes ok,
# 0 data races.
# ─────────────────────────────────────────────────────────────

set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"

# ── Localizar zig ────────────────────────────────────────────────────────
# Orden: variable ZIG → PATH → el que dejó `pip install --user ziglang`
# (que cae en el site-packages del usuario, no en el PATH).
localizar_zig() {
  if [ -n "${ZIG:-}" ]; then printf '%s\n' "$ZIG"; return; fi
  if command -v zig >/dev/null 2>&1; then command -v zig; return; fi

  # Vía Python: importa el paquete y saca la ruta del ejecutable.
  local py cand
  for py in python python3 py; do
    command -v "$py" >/dev/null 2>&1 || continue
    cand="$("$py" -c 'import os, ziglang; print(os.path.join(os.path.dirname(ziglang.__file__), "zig.exe"))' 2>/dev/null || true)"
    [ -n "$cand" ] && [ -f "$cand" ] && { printf '%s\n' "$cand"; return; }
  done

  # Último recurso: el site-packages del usuario, que es donde lo deja pip.
  for cand in \
    "$HOME"/AppData/Roaming/Python/Python3*/site-packages/ziglang/zig.exe \
    /c/Users/*/AppData/Roaming/Python/Python3*/site-packages/ziglang/zig.exe; do
    [ -f "$cand" ] && { printf '%s\n' "$cand"; return; }
  done
}

ZIG_EXE="$(localizar_zig)"
if [ -z "${ZIG_EXE:-}" ]; then
  echo "ERROR: no encontré zig." >&2
  echo "       Instalalo con:  pip install --user ziglang" >&2
  exit 1
fi

# Go es un binario de Windows, así que CC tiene que ser una ruta de Windows
# (C:/...) y no una de Git Bash (/c/...). cygpath -m deja barras normales, que
# Go acepta, y evita los backslashes que bash interpretaría como escapes.
ZIG_WIN="$ZIG_EXE"
if command -v cygpath >/dev/null 2>&1; then
  ZIG_WIN="$(cygpath -m "$ZIG_EXE")"
fi

# Los paquetes van en array (no en un string) para que cada uno llegue como un
# argumento suelto; con comillas, go recibe un solo argumento y no matchea nada.
if [ "$#" -eq 0 ]; then
  PAQUETES=(./...)
else
  PAQUETES=("$@")
fi

export CC="$ZIG_WIN cc"
export CGO_ENABLED=1
# Las dos banderas del encabezado: la API set que aporta los símbolos de
# sincronización y la base de imagen que mantiene el shadow dentro del rango.
export CGO_LDFLAGS="-lapi-ms-win-core-synch-l1-2-0 -Wl,--image-base,0x400000"

echo "==> zig      : $ZIG_EXE ($("$ZIG_EXE" version))"
echo "==> go       : $(go version)"
echo "==> paquetes : ${PAQUETES[*]}"
echo "==> race     : activado (CGO_ENABLED=1)"
echo

cd "$RAIZ/go_backend"
# -count=1 evita que la caché de resultados oculte una carrera ya reportada.
go test -race "${PAQUETES[@]}" -count=1
