#!/usr/bin/env bash
#
# release.sh — Lanza la versión nueva (Android + PC) y publica la GitHub
# Release con los NOMBRES CONSISTENTES que leen la app y el sitio web:
#
#   Android:  app-arm64-v8a-release.apk
#             app-armeabi-v7a-release.apk
#             app-x86_64-release.apk
#   Windows:  Bitly-Setup-X.Y.Z.exe
#
# Flujo:
#   1. Lee la versión actual de pubspec.yaml (X.Y.Z+CODE) y la sube.
#   2. Compila los APKs con --split-per-abi (un APK por arquitectura) y el
#      instalador de Windows (scripts/build_windows_release.sh).
#   3. Commitea el bump, crea el tag vX.Y.Z y hace push.
#   4. Crea la GitHub Release con notas en español (primario) e inglés
# Uso:
#   bash scripts/release.sh              # sube +0.0.1 (patch)
#   bash scripts/release.sh 0.9.10       # fija una versión exacta
#
# Parte del flujo: release (Android + Windows).

set -euo pipefail

cd "$(dirname "$0")/../.."

HACER_WINDOWS="false"
SUBIR_RELEASE="false"
for arg in "$@"; do
  case "$arg" in
    --windows) HACER_WINDOWS="true" ;;
    --upload) SUBIR_RELEASE="true" ;;
  esac
done

CURRENT=$(grep -E '^version:' pubspec.yaml | sed 's/version: *//' | tr -d ' \r')
echo "Versión actual: $CURRENT"

if [[ "$CURRENT" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)$ ]]; then
  MAJOR="${BASH_REMATCH[1]}"
  MINOR="${BASH_REMATCH[2]}"
  PATCH="${BASH_REMATCH[3]}"
  CODE="${BASH_REMATCH[4]}"
else
  echo "::error::Formato de versión inesperado en pubspec.yaml: '$CURRENT' (esperado X.Y.Z+N)" >&2
  exit 1
fi

if [[ -n "${1:-}" && "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  NEW_VERSION="$1"
  IFS='.' read -r MAJOR MINOR PATCH <<< "$NEW_VERSION"
else
  PATCH=$((PATCH + 1))
fi
CODE=$((CODE + 1))
NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

echo "Nueva versión: $NEW_VERSION+$CODE"

if git rev-parse "v${NEW_VERSION}" >/dev/null 2>&1; then
  echo "::error::El tag v${NEW_VERSION} ya existe" >&2
  exit 1
fi

# ── 1) Bump de versión ──────────────────────────────────────────────
sed -i "s/^version: .*/version: ${NEW_VERSION}+${CODE}/" pubspec.yaml
echo "Bump aplicado: version: ${NEW_VERSION}+${CODE}"

# `flutter pub get` reescribe el registrant de plugins incluyendo las
# dependencias de DESARROLLO (integration_test) cuando el pubspec cambia. Si
# eso pasara DENTRO de `flutter build apk`, el release heredaría un registrant
# sucio y Gradle fallaría ("package dev.flutter.plugins.integration_test does
# not exist"). Se corre acá, antes de borrar el registrant, para que el build
# lo regenere limpio (release descarta las dev dependencies).
flutter pub get >/dev/null
echo "Dependencias sincronizadas."

# ── 2) Compilar binarios ────────────────────────────────────────────
mkdir -p dist

# El registrant de plugins es un archivo GENERADO que queda sucio si antes se
# corrió `flutter test` o un build de debug: incluye plugins de test
# (integration_test) y el release no compila ("package dev.flutter.plugins.
# integration_test does not exist"). Borrarlo hace que Flutter lo regenere
# limpio para release.
rm -f android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java

# El APK x86_64 (emulador / Chromebook) NO entra por defecto: build.gradle.kts
# lo excluye salvo INCLUDE_X86_64=true. Como acá SIEMPRE se publican los 3
# APKs, se activa explícitamente.
export INCLUDE_X86_64="${INCLUDE_X86_64:-true}"

echo "==> Compilando APKs (split-per-abi, INCLUDE_X86_64=$INCLUDE_X86_64)..."
flutter build apk --release --split-per-abi
# Nombres consistentes (los que ya genera Flutter — no se renombran):
APKS=(
  "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
  "build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk"
  "build/app/outputs/flutter-apk/app-x86_64-release.apk"
)
for apk in "${APKS[@]}"; do
  if [[ ! -f "$apk" ]]; then
    echo "::error::Falta $apk" >&2
    exit 1
  fi
  cp "$apk" "dist/$(basename "$apk")"
done

if [[ "$HACER_WINDOWS" == "true" ]]; then
  echo "==> Compilando instalador Windows..."
  bash scripts/build_windows_release.sh
fi

echo "==> Artefactos en dist/:"
ls -lh dist/

# ── 3) Commit + tag + push ──────────────────────────────────────────
# Solo el bump va al repo; los binarios se suben a la GitHub Release
# (nunca se commitean APKs/instaladores al git).
git add pubspec.yaml
git commit -m "release: v${NEW_VERSION} — Android + PC (${NEW_VERSION}+${CODE})

Release: v${NEW_VERSION} — Android + PC (${NEW_VERSION}+${CODE})"
git tag "v${NEW_VERSION}"
git push origin main
git push origin "v${NEW_VERSION}"

echo ""
echo "✅ Tag v${NEW_VERSION} publicado."

# ── 4) Crear la GitHub Release (notas ES primario + EN secundario) ──
if [[ "$SUBIR_RELEASE" == "true" ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "::error::gh (GitHub CLI) no está instalado" >&2
    exit 1
  fi

  # Las notas van sin interpolar ($ y backticks romperían el heredoc) y la
  # versión se sustituye después con __VERSION__.
  NOTAS_ES=$(cat <<'EOF'
## 🎵 Bitly v__VERSION__ — Android + PC + TV + macOS + iOS

### ✨ Novedades
- **La versión web ya reproduce música (player nuevo en el navegador)**: la lógica de reproducción —cola, crossfade, precarga, anti-cortes, velocidad y volumen— ahora habla contra una interfaz de audio, y cada plataforma la implementa: media_kit/mpv en Android/Mac/PC/TV y el reproductor HTML del navegador en la web.
- **El motor se elige al compilar, no en tiempo de ejecución**: cuando se compila para Android/PC, el código de la web ni se mira (y al revés). Nada cambia en las plataformas que ya usabas: mismo motor, misma configuración, mismo sonido.
- **La web ahora explica qué necesita en vez de mostrar un error técnico**: si abrís la versión web sin el servidor de Bitly encendido, aparece una pantalla que cuenta por qué la web lo necesita (los navegadores no pueden pedir la música por su cuenta) y te manda a la app de Android/Windows/macOS/iOS, que no necesita nada extra. Antes decía "Backend no responde" con un botón que nunca iba a funcionar.
- **Un bug clásico de volumen, cerrado en un solo lugar**: mpv mide el volumen de 0 a 100 y el navegador de 0 a 1. La conversión ahora vive en el motor de cada plataforma, así no puede volver el fallo de "reproduce a 1% e inaudible".

### ✅ Verificado en un navegador real
El player web se probó de punta a punta en Chrome contra un audio remoto: duración detectada (6:12), la posición avanza, salto dentro del tema (60 s), volumen, velocidad 1.5x, pausa/reanudar, detener y liberación del motor. Todo en verde. La app además compila para web y arranca sin excepciones.

### ⚠️ Sobre la versión web
La web funciona con el servidor de Bitly (`bitly-backend --web`) encendido en tu computadora o en un servidor propio: no es una app que se instala sola y no se descarga desde acá. Se abre desde el navegador de esa misma máquina, o desde otro dispositivo de la misma red.

### ⬇️ Descargas
- Android: app-arm64-v8a-release.apk / app-armeabi-v7a-release.apk / app-x86_64-release.apk
- Windows: Bitly-Setup-__VERSION__.exe
- macOS/iOS: se generan en el workflow de Apple (link en la release).
- TV (Android TV / Google TV / Fire TV): instalá app-arm64-v8a-release.apk con Downloader.
EOF
)
  NOTAS_EN=$(cat <<'EOF'

---

## 🎵 Bitly v__VERSION__ — Android + PC + TV + macOS + iOS

### ✨ Highlights
- **The web version now plays music (new browser player)**: the playback logic —queue, crossfade, preloading, stall watchdogs, speed and volume— now talks to an audio interface, and each platform implements it: media_kit/mpv on Android/Mac/PC/TV and the browser's HTML player on the web.
- **The engine is chosen at build time, not at runtime**: when you build for Android/PC, the web code is not even looked at (and vice versa). Nothing changes on the platforms you already use: same engine, same configuration, same sound.
- **The web now explains what it needs instead of showing a technical error**: if you open the web version without the Bitly server running, you get a screen that explains why the web needs it (browsers cannot fetch the music on their own) and points you to the Android/Windows/macOS/iOS app, which needs nothing extra. It used to say "Backend not responding" with a button that was never going to work.
- **A classic volume bug, closed in one place**: mpv measures volume 0-100 and the browser 0-1. The conversion now lives in each platform's engine, so the "plays at 1% and inaudible" failure cannot come back.

### ✅ Verified in a real browser
The web player was tested end to end in Chrome against a remote audio file: duration detected (6:12), position advancing, seek within the track (60 s), volume, 1.5x speed, pause/resume, stop and engine disposal. All green. The app also builds for web and boots with no exceptions.

### ⚠️ About the web version
The web version runs with the Bitly server (`bitly-backend --web`) turned on, on your computer or on a server of your own: it is not an app that installs itself, and it is not downloaded from here. You open it from a browser on that same machine, or from another device on the same network.

### ⬇️ Downloads
- Android: app-arm64-v8a-release.apk / app-armeabi-v7a-release.apk / app-x86_64-release.apk
- Windows: Bitly-Setup-__VERSION__.exe
- macOS/iOS: generated in the Apple workflow (link in release).
- TV (Android TV / Google TV / Fire TV): install app-arm64-v8a-release.apk with Downloader.
EOF
)
  # La versión real entra acá (los heredocs de arriba no interpolan nada).
  NOTAS_ES="${NOTAS_ES//__VERSION__/$NEW_VERSION}"
  NOTAS_EN="${NOTAS_EN//__VERSION__/$NEW_VERSION}"

  echo "==> Creando GitHub Release v${NEW_VERSION}..."
  gh release create "v${NEW_VERSION}" \
    --repo QuopTron/bitly \
    --title "Bitly v${NEW_VERSION} — Android + PC + TV + macOS + iOS" \
    --notes "${NOTAS_ES}${NOTAS_EN}" \
    dist/app-arm64-v8a-release.apk \
    dist/app-armeabi-v7a-release.apk \
    dist/app-x86_64-release.apk \
    dist/Bitly-Setup-${NEW_VERSION}.exe
  echo ""
  echo "✅ Release publicado: https://github.com/QuopTron/bitly/releases/tag/v${NEW_VERSION}"
else
  echo ""
  echo "✅ Listo. Para SUBIR el release (con --upload), los binarios ya están en dist/."
  echo "   Subida manual: GitHub → Releases → Edit release → Drag & drop en 'Attach binaries'."
fi