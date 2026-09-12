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
#      (secundario) y sube los binarios como "Attach binaries".
#
# Uso:
#   bash scripts/release.sh              # sube +0.0.1 (patch)
#   bash scripts/release.sh 0.9.10       # fija una versión exacta
#   bash scripts/release.sh --windows    # además compila el instalador Windows
#   bash scripts/release.sh --upload     # compila TODO y sube el release
#
# Parte del flujo: release (Android + Windows).

set -euo pipefail

cd "$(dirname "$0")/.."

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
- **Streaming sin sesión mejorado**: se modernizaron los clientes InnerTube de YouTube (nuevo cliente `visionos`, UA de Cobalt real, `tv_downgraded`, `embedUrl` anti-detección). YouTube reproduce audio solo-audio de mejor calidad sin iniciar sesión y sin proveedor externo.
- **ISRC derivado automáticamente**: cuando la fuente (YouTube/SoundCloud) no expone ISRC, la app busca la misma canción en Deezer/Qobuz/Tidal/Apple, verifica que sea el original por título+artista+duración y usa su ISRC. Esto habilita el rescate FLAC sin login.
- **Matching reforzado por duración**: dos subidas con el mismo título y artista (common en YouTube/SoundCloud) ahora se desempatan por duración, así sirve la versión correcta.
- **Bitly en tu Smart TV**: el mismo APK se instala en Android TV, Google TV y Fire TV, usa el diseño de escritorio y aparece en el menú de la TV.
- **Tutorial interactivo**: la app guía paso a paso por feed, fuentes, búsqueda, reproducción, miniplayer, ajustes y Premium (con spotlight, flechas, skip por paso o todo).

### 🐛 Correcciones
- **YouTube**: duración de los tracks ahora en milisegundos (antes mostraba 0:00 y la verificación fallaba).
- **SABR de YouTube**: clientes que devuelven respuestas sin URLs usables ahora se saltan automáticamente (ya no pagan un POST extra por canción).
- **Enlaces de Spotify/YouTube**: pegar un enlace resuelve y reproduce correctamente.
- **Descargas paralelas**: rescate de FLAC más rápido y con más opciones de calidad.
- **Reproductor**: miniplayer, notificación y reproductor grande muestran siempre la misma canción.

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
- **YouTube streaming without login**: modernized InnerTube clients (new `visionos` anchor, real Cobalt UA, `tv_downgraded`, anti-detection `embedUrl`). YouTube plays higher-quality audio-only without login.
- **Auto-derived ISRC**: when the source (YouTube/SoundCloud) has no ISRC, the app finds the same track in Deezer/Qobuz/Tidal/Apple, verifies it's the original by title+artist+duration, and uses its ISRC. This enables FLAC rescue without login.
- **Duration-aware matching**: duplicate uploads with the same title+artist are now desempated by duration, serving the correct version.
- **Bitly on Smart TV**: the same APK installs on Android TV, Google TV and Fire TV, uses the desktop layout and appears in the TV launcher.
- **Interactive tutorial**: first-time guided tour through feed, sources, search, playback, miniplayer, settings and Premium.

### 🐛 Fixes
- **YouTube duration**: track durations now in milliseconds (was showing 0:00 and verification was failing).
- **YouTube SABR**: clients returning empty format lists are now skipped automatically.
- **Spotify/YouTube links**: pasting a link resolves and plays correctly.
- **Parallel downloads**: faster FLAC rescue with more quality options.
- **Player**: miniplayer, notification and full player always show the same playing track.

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