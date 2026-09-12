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

# ── 2) Compilar binarios ────────────────────────────────────────────
mkdir -p dist
echo "==> Compilando APKs (split-per-abi)..."
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
## 🎵 Bitly v__VERSION__ — Android + PC + TV

### ✨ Novedades
- **Bitly en tu Smart TV**: el mismo APK ahora se instala en Android TV, Google TV y Fire TV, aparece en el menú de la TV y usa el diseño de escritorio adaptado a la pantalla grande.
- **Tutorial interactivo de primera vez**: la app te guía paso a paso (con foco sobre cada elemento) por el feed, las fuentes, la búsqueda, la reproducción, el miniplayer, los ajustes y Premium. Podés saltar un paso o el tutorial completo.
- **Indicador de red**: ves el estado de tu conexión y su calidad sin salir de la app.
- **Búsquedas y metadatos más rápidos**: caché y precarga de metadatos de todas las fuentes.
- **Sesiones firmadas con rotación**: menos caídas al verificar las fuentes.

### 🐛 Correcciones
- **Audio de YouTube**: cuando hay proveedor de PO Token se priorizan los formatos solo-audio de mayor calidad en vez del itag=18.
- **Enlaces de Spotify y YouTube**: pegar un enlace ahora lo resuelve y lo reproduce bien.
- **Descargas paralelas y rescate de FLAC**: descargas más rápidas y con más opciones de calidad.
- **Reproductor**: el miniplayer, la notificación y el reproductor grande muestran siempre la misma canción que suena.

### ⬇️ Descargas
- Android: app-arm64-v8a-release.apk / app-armeabi-v7a-release.apk / app-x86_64-release.apk
- Windows: Bitly-Setup-__VERSION__.exe
- TV (Android TV / Google TV / Fire TV): instalá app-arm64-v8a-release.apk con la app Downloader.
EOF
)
  NOTAS_EN=$(cat <<'EOF'

---

## 🎵 Bitly v__VERSION__ — Android + PC + TV

### ✨ Highlights
- **Bitly on your Smart TV**: the same APK now installs on Android TV, Google TV and Fire TV, shows up in the TV launcher and uses the desktop layout adapted to the big screen.
- **First-time interactive tutorial**: the app walks you through (with a spotlight on each element) the feed, sources, search, playback, miniplayer, settings and Premium. You can skip a step or the whole tutorial.
- **Network indicator**: see your connection status and quality without leaving the app.
- **Faster search and metadata**: caching and precaching for every source's metadata.
- **Signed sessions with rotation**: fewer failures when verifying sources.

### 🐛 Fixes
- **YouTube audio**: when a PO Token provider is available, higher-quality audio-only formats are preferred over itag=18.
- **Spotify and YouTube links**: pasting a link now resolves and plays correctly.
- **Parallel downloads and FLAC rescue**: faster downloads with more quality options.
- **Player**: miniplayer, notification and the full player always show the same track that is playing.

### ⬇️ Downloads
- Android: app-arm64-v8a-release.apk / app-armeabi-v7a-release.apk / app-x86_64-release.apk
- Windows: Bitly-Setup-__VERSION__.exe
- TV (Android TV / Google TV / Fire TV): install app-arm64-v8a-release.apk with the Downloader app.
EOF
)
  # La versión real entra acá (los heredocs de arriba no interpolan nada).
  NOTAS_ES="${NOTAS_ES//__VERSION__/$NEW_VERSION}"
  NOTAS_EN="${NOTAS_EN//__VERSION__/$NEW_VERSION}"

  echo "==> Creando GitHub Release v${NEW_VERSION}..."
  gh release create "v${NEW_VERSION}" \
    --repo QuopTron/bitly \
    --title "Bitly v${NEW_VERSION} — Android + PC" \
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