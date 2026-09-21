#!/usr/bin/env bash
#
# emulador.sh — Compila el APK del EMULADOR (x86_64) y lo instala,
# VERIFICANDO que lo que quedó en el dispositivo sea el build recién hecho.
#
# Por qué existe: `flutter build apk --release --split-per-abi` NO arma el
# x86_64 salvo INCLUDE_X86_64=true (ver android/app/build.gradle.kts). Si el
# flag falta, Gradle deja el `app-x86_64-release.apk` VIEJO en su sitio y el
# `adb install` responde "Success" instalando código de ayer: el síntoma es
# "hice cambios y no se ven" y se pierde una tarde buscando el bug en el código.
# Por eso acá:
#   1. se borra el APK viejo antes de compilar (para que no quede de trampa),
#   2. se compila con INCLUDE_X86_64=true,
#   3. después de instalar se compara el SHA-256 del APK compilado con el del
#      APK que quedó instalado y se FALLA si no coinciden.
#
# Uso:
#   bash scripts/dev/emulador.sh                 # compila + instala + verifica
#   bash scripts/dev/emulador.sh --solo-instalar # usa el APK ya compilado
#
# ADB: se usa la variable de entorno ADB si está seteada; si no, `adb` del PATH.
#
# Parte del flujo: desarrollo (probar cambios en el emulador).

set -euo pipefail

# Git Bash en Windows convierte las rutas de adb (`/data/local/tmp`) a rutas de
# Windows y los comandos fallan con "not directory". Se desactiva esa conversión.
export MSYS_NO_PATHCONV=1

cd "$(dirname "$0")/../.."

ADB="${ADB:-adb}"
PAQUETE="com.example.bitly"
APK="build/app/outputs/flutter-apk/app-x86_64-release.apk"
SOLO_INSTALAR="${1:-}"

info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m $*"; }
fail() { echo -e "\033[1;31m[FAIL]\033[0m $*"; exit 1; }

dispositivos="$("$ADB" devices | grep -c "device$" || true)"
[ "$dispositivos" -ge 1 ] || fail "no hay ningún dispositivo/emulador conectado (adb devices)"

if [ "$SOLO_INSTALAR" != "--solo-instalar" ]; then
  info "Borrando el APK x86_64 viejo (evita instalar un build de ayer)..."
  rm -f "$APK"

  info "Compilando APK x86_64 (INCLUDE_X86_64=true)..."
  INCLUDE_X86_64=true flutter build apk --release --split-per-abi \
    --target-platform android-x64

  [ -f "$APK" ] || fail "no se generó $APK (¿el build falló?)"
  ok "APK: $APK ($(du -h "$APK" | cut -f1))"
fi

[ -f "$APK" ] || fail "no existe $APK: corré el script sin --solo-instalar"

info "Instalando en el emulador..."
"$ADB" install -r "$APK" | tail -1

# ── Verificación de que lo instalado ES este APK ──────────────────────────
info "Verificando que el dispositivo tenga ESTE build..."
ruta="$("$ADB" shell pm path "$PAQUETE" | sed 's/package://' | tr -d '\r\n')"
[ -n "$ruta" ] || fail "no se pudo leer la ruta del APK instalado"

"$ADB" shell rm -f /data/local/tmp/bitly_check.apk >/dev/null 2>&1 || true
"$ADB" shell cp "$ruta" /data/local/tmp/bitly_check.apk
"$ADB" pull /data/local/tmp/bitly_check.apk build/instalado_check.apk >/dev/null

local_sha="$(sha256sum "$APK" | cut -d' ' -f1)"
inst_sha="$(sha256sum build/instalado_check.apk | cut -d' ' -f1)"
rm -f build/instalado_check.apk

if [ "$local_sha" != "$inst_sha" ]; then
  fail "lo instalado NO es este build (¿otro ABI o un APK viejo?). Revisá $APK"
fi
ok "Instalado y verificado: los cambios están en el dispositivo"

info "Arrancando la app..."
"$ADB" shell am force-stop "$PAQUETE" || true
# `am start` y no `monkey`: algunos emuladores no traen monkey instalado y el
# chequeo de abajo fallaba sin decir por qué.
"$ADB" shell am start -n "$PAQUETE/.MainActivity" >/dev/null 2>&1
sleep 10
if [ -z "$("$ADB" shell pidof "$PAQUETE" | tr -d '\r')" ]; then
  fail "la app no quedó corriendo (mirá: adb logcat | grep AndroidRuntime)"
fi
ok "App corriendo"
