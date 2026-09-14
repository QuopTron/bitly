#!/usr/bin/env bash
#
# build_windows_release.sh — Compila la app Windows en release y arma el
# instalador .exe con Inno Setup.
#
# Qué hace:
#   1. Cierra la app si está corriendo (bitly.exe / bitly-backend.exe).
#   2. Compila el backend Go (Windows) para la arquitectura destino.
#   3. Compila el build de Windows release de Flutter.
#   4. Verifica que el bundle traiga el runtime de Visual C++ (ver abajo).
#   5. Borra sesiones firmadas del Release (el instalador debe salir SIEMPRE
#      limpio para forzar verificar las extensiones en cada instalación).
#   6. Compila el instalador con Inno Setup (scripts/build/instalador_windows.iss).
#   7. Deja el instalador en dist/Bitly-Setup-X.Y.Z[-arm64].exe.
#
# Arquitecturas:
#   Sin argumento usa la del HOST (x64 o arm64). Flutter para Windows compila
#   para la arquitectura del host, así que pedir arm64 desde una PC x64 no es
#   posible: se avisa y no se compila algo que no arrancaría.
#
#     bash scripts/build/build_windows_release.sh            # host
#     bash scripts/build/build_windows_release.sh arm64      # en una PC ARM
#
# Por qué se verifica el runtime de C++:
#   bitly.exe, flutter_windows.dll y los DLLs de plugins se compilan con MSVC y
#   enlazan dinámicamente contra el CRT (msvcp140.dll, vcruntime140.dll…). Si
#   esas DLLs no viajan en el bundle, la app SOLO arranca en una PC que ya tenga
#   instalado el "Redistribuible de Visual C++ 2015-2022"; en una PC nueva
#   Windows muestra "no se encuentra VCRUNTIME140.dll" y el proceso se cierra.
#   Eso es lo que se reportaba como "el exe no es compatible con las
#   arquitecturas nuevas". El empaquetado del CRT lo hace windows/CMakeLists.txt
#   con InstallRequiredSystemLibraries (y da el CRT de la arquitectura correcta).
#   Acá solo se comprueba, porque un bundle sin CRT es un instalador roto que
#   recién se descubre en la PC del usuario.
#
# Uso:
#   bash scripts/build/build_windows_release.sh
#
# Parte del flujo: release de escritorio (Windows).

set -euo pipefail
cd "$(dirname "$0")/../.."

# ── Arquitectura destino ────────────────────────────────────────────────────
ARCH_IN="${1:-}"
if [[ -z "$ARCH_IN" ]]; then
  case "$(uname -m)" in
    aarch64|arm64|ARM64) ARCH="arm64" ;;
    *)                   ARCH="x64" ;;
  esac
else
  case "$ARCH_IN" in
    x64|x86_64|amd64) ARCH="x64" ;;
    arm64|aarch64)    ARCH="arm64" ;;
    *)
      echo "::error::Arquitectura desconocida: $ARCH_IN (usá x64 o arm64)" >&2
      exit 1
      ;;
  esac
fi

HOST_ARCH="x64"
case "$(uname -m)" in aarch64|arm64|ARM64) HOST_ARCH="arm64" ;; esac
if [[ "$ARCH" != "$HOST_ARCH" ]]; then
  echo "::error::Flutter para Windows compila solo para la arquitectura del host" >&2
  echo "          (host=$HOST_ARCH, pedido=$ARCH). Corré este script en una PC $ARCH." >&2
  exit 1
fi

GOARCH="amd64"
[[ "$ARCH" == "arm64" ]] && GOARCH="arm64"

RELEASE="build/windows/$ARCH/runner/Release"

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

echo "==> 1/6 Cerrando la app si está corriendo... ($ARCH)"
taskkill //F //IM bitly.exe 2>/dev/null || true
taskkill //F //IM bitly-backend.exe 2>/dev/null || true
sleep 1

echo "==> 2/6 Compilando backend Go (Windows $GOARCH)..."
mkdir -p windows/backend
(cd go_backend && GOOS=windows GOARCH="$GOARCH" go build -ldflags="-s -w" -o "../windows/backend/bitly-backend.exe" ./cmd/server)

echo "==> 3/6 Compilando Windows release... ($ARCH)"
flutter build windows --release

if [[ ! -d "$RELEASE" ]]; then
  echo "::error::No existe $RELEASE — el build salió en otra arquitectura." >&2
  ls -d build/windows/*/ 2>/dev/null || true
  exit 1
fi

echo "==> 4/6 Verificando el runtime de Visual C++ en el bundle..."
# La comprobación vive en su propio script para que el CI use EXACTAMENTE la
# misma y no se pueda colar un bundle sin CRT por un paso distinto.
bash scripts/build/check_windows_bundle.sh "$RELEASE"

echo "==> 5/6 Limpiando sesiones firmadas del Release..."
rm -rf "$RELEASE/signed_sessions" "$RELEASE/ext_data/signed_sessions"
rm -f "$RELEASE/signed_session_debug.log" "$RELEASE/ext_data/signed_session_debug.log"
rm -f "$RELEASE"/*_store.json 2>/dev/null || true

# La versión del instalador sale del pubspec (sin el build number) para que
# el asset quede como Bitly-Setup-<versión>.exe, el nombre que leen la app y
# el sitio web del proyecto.
VERSION=$(grep -E '^version:' pubspec.yaml | sed 's/version: *//' | cut -d'+' -f1)
echo "==> 6/6 Compilando instalador con Inno Setup (v$VERSION, $ARCH)..."
mkdir -p dist
# MSYS_NO_PATHCONV=1: sin esto, Git Bash convierte "/DMyAppVersion=..." en
# una ruta de Windows y ISCC cree que recibe dos scripts (error
# "more than one script filename").
ISCC_DEFS=("/DMyAppVersion=$VERSION" "/DMyBuildArch=$ARCH")
[[ "$ARCH" == "arm64" ]] && ISCC_DEFS+=("/DMyBuildArm64")
MSYS_NO_PATHCONV=1 "$ISCC" "${ISCC_DEFS[@]}" scripts/build/instalador_windows.iss

SUFFIX=""
[[ "$ARCH" == "arm64" ]] && SUFFIX="-arm64"

echo ""
echo "✅ Instalador listo: dist/Bitly-Setup-$VERSION$SUFFIX.exe ($ARCH)"
