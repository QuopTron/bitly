[bookmarks] Loaded 0 bookmarks
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
[kit] VS installation instance not found for kit "Visual Studio Community 2026 Preview - amd64_x86" - (c9f181c5). It is recommended that you re-scan the kits and also remove any user-local entries that are no longer present on the system.
[kit] VS installation instance not found for kit "Visual Studio Community 2026 Preview - amd64_x86" - (c9f181c5). It is recommended that you re-scan the kits and also remove any user-local entries that are no longer present on the system.
# Uso:
#   bash scripts/release.sh              # sube +0.0.1 (patch)
#   bash scripts/release.sh 0.9.10       # fija una versión exacta
[proc] The command: make --version failed with error: Error: spawn make ENOENTs
[main] Unable to determine what CMake generator to use. Please install or configure a preferred generator, or update settings.json, your Kit configuration or PATH variable. Error: Not usable generator found.
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
- **Se acabó el "cae en un remix"**: el backend estaba excluyendo a Deezer, Amazon y Apple Music del streaming y la descarga (sus manifest solo declaraban metadata), así que casi todo terminaba en un re-subido de YouTube/SoundCloud. Ahora entran como fuentes de audio y **las fuentes exactas van primero**: si Deezer/Qobuz/Tidal/Amazon pueden servir la canción, nunca se baja a un re-subido.
- **ISRC con autoridad**: solo los catálogos (y el rescate indexado por ISRC) confirman la identidad de una grabación. YouTube/SoundCloud ya no "heredan" el ISRC de una canción por parecido de nombre (era justo cómo un remix pasaba por el original).
- **Nueva fuente: Internet Archive** — FLAC real y catálogo abierto **sin cuenta, sin sesión y sin gateway**. Se suma a la búsqueda, el feed, la reproducción y la descarga.
- **Sin dependencia de gateways externos**: el audio ya no pasa por api.zarz.moe; las fuentes exactas resuelven por ISRC contra catálogos públicos.
- **Deezer y Amazon descargables**: sus manifest ahora declaran `download_provider`, con lo que el rescate de FLAC por ISRC sí los prueba.

### 🐛 Correcciones
- **Deezer resuelve por ISRC**: su extensión exporta `resolveTrackIDFromISRC` (la función ya existía pero no estaba expuesta), así una petición con ISRC deja de caer a una búsqueda por nombre.
- **Búsqueda por ISRC estricta**: ya no devuelve el primer resultado a ciegas; exige que el candidato declare el ISRC.
- **YouTube**: duración de los tracks ahora en milisegundos (antes mostraba 0:00 y la verificación fallaba).
- **SABR de YouTube**: clientes que devuelven respuestas sin URLs usables ahora se saltan automáticamente (ya no pagan un POST extra por canción).
- **Enlaces de Spotify/YouTube**: pegar un enlace resuelve y reproduce correctamente.
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
- **No more "it falls back to a remix"**: the backend was excluding Deezer, Amazon and Apple Music from streaming and download (their manifests declared metadata only), so almost everything ended up on a YouTube/SoundCloud re-upload. They now serve audio, and **exact sources go first**: if Deezer/Qobuz/Tidal/Amazon can serve the track, it never falls back to a re-upload.
- **Authoritative ISRC**: only catalogs (and the ISRC-indexed rescue) confirm a recording's identity. YouTube/SoundCloud no longer "inherit" an ISRC by name similarity (which was exactly how a remix passed as the original).
- **New source: Internet Archive** — real FLAC and an open catalog with **no account, no session and no gateway**. It joins search, feed, playback and download.
- **No external gateway dependency**: audio no longer goes through api.zarz.moe; exact sources resolve by ISRC against public catalogs.
- **Deezer and Amazon are downloadable**: their manifests now declare `download_provider`, so ISRC-based FLAC rescue actually tries them.

### 🐛 Fixes
- **Deezer resolves by ISRC**: its extension now exports `resolveTrackIDFromISRC` (the function existed but wasn't exposed), so an ISRC request no longer falls back to a name search.
- **Strict ISRC lookup**: it no longer returns the first result blindly; the candidate must declare the ISRC.
- **YouTube duration**: track durations now in milliseconds (was showing 0:00 and verification was failing).
- **YouTube SABR**: clients returning empty format lists are now skipped automatically.
- **Spotify/YouTube links**: pasting a link resolves and plays correctly.
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