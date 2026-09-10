#!/usr/bin/env bash
#
# build_windows_release.sh — Compila la app Windows en release y arma el
# instalador .exe con Inno Setup.
#
# Qué hace:
#   1. Cierra la app si está corriendo (bitly.exe / bitly-backend.exe).
#   2. Compila el build de Windows release de Flutter.
#   3. Borra sesiones firmadas del Release (el instalador debe salir SIEMPRE
#      limpio para forzar verificar las extensiones en cada instalación).
#   4. Compila el instalador con Inno Setup (scripts/instalador_windows.iss).
#   5. Deja el instalador en dist/Bitly_vX.Y.Z_Windows-Instalador.exe.
#
# Uso:
#   bash scripts/build_windows_release.sh
#
# Parte del flujo: release de escritorio (Windows).

set -euo pipefail
cd "$(dirname "$0")/.."

ISCC="${ISCC:-}"
if [[ -z "$ISCC" ]]; then
  for p in \
    "$LOCALAPPDATA/Programs/Inno Setup 6/ISCC.exe" \
    "/c/Program Files (x86)/Inno Setup 6/ISCC.exe" \
    "/c/Program Files/Inno Setup 6/ISCC.exe"; do
    if [[ -f "$p" ]]; then ISCC="$p"; break; fi
  done
fi
if [[ -z "$ISCC" || ! -f "$ISCC" ]]; then
  echo "::error::No se encontró ISCC.exe (Inno Setup 6). Instálalo con:" >&2
  echo "  winget install --id JRSoftware.InnoSetup -e --silent" >&2
  exit 1
fi

echo "==> 1/4 Cerrando la app si está corriendo..."
taskkill //F //IM bitly.exe 2>/dev/null || true
taskkill //F //IM bitly-backend.exe 2>/dev/null || true
sleep 1

echo "==> 2/4 Compilando backend Go (Windows)..."
mkdir -p windows/backend
(cd go_backend && go build -ldflags="-s -w" -o "../windows/backend/bitly-backend.exe" ./cmd/server)

echo "==> 3/5 Compilando Windows release..."
flutter build windows --release

RELEASE="build/windows/x64/runner/Release"

echo "==> 4/5 Limpiando sesiones firmadas del Release..."
rm -rf "$RELEASE/signed_sessions" "$RELEASE/ext_data/signed_sessions"
rm -f "$RELEASE/signed_session_debug.log" "$RELEASE/ext_data/signed_session_debug.log"
rm -f "$RELEASE"/*_store.json 2>/dev/null || true

# La versión del instalador sale del pubspec (sin el build number) para que
# el asset quede como Bitly-Setup-<versión>.exe, el nombre que leen la app y
# el sitio web del proyecto.
VERSION=$(grep -E '^version:' pubspec.yaml | sed 's/version: *//' | cut -d'+' -f1)
echo "==> 5/5 Compilando instalador con Inno Setup (v$VERSION)..."
mkdir -p dist
# MSYS_NO_PATHCONV=1: sin esto, Git Bash convierte "/DMyAppVersion=..." en
# una ruta de Windows y ISCC cree que recibe dos scripts (error
# "more than one script filename").
MSYS_NO_PATHCONV=1 "$ISCC" "/DMyAppVersion=$VERSION" scripts/instalador_windows.iss

echo ""
echo "✅ Instalador listo: dist/Bitly-Setup-$VERSION.exe"