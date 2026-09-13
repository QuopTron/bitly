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
- **Búsquedas de Internet Archive de 5 a 8 veces más rápidas**: la lectura de la metadata de cada item ahora es secuencial. archive.org degrada las peticiones en ráfaga (medido: 8 items tardaban 2,5 s de uno en uno contra 7,9 s con 4 en paralelo), así que la búsqueda completa bajó de 8-14 s a 1,6-4,2 s. Además se corta apenas hay suficientes pistas y se acota cuántos items se leen.
- **Internet Archive ahora encuentra la canción, no una colección ajena**: se busca primero la frase en el título del item y solo si no hay nada se cae al texto libre (que busca también en la descripción, y por eso devolvía resultados de otros discos). "Miles Davis Kind of Blue" pasó de devolver desconocidos a devolver el disco correcto.
- **El audio de Internet Archive arranca ~3 veces más rápido**: las URLs salen apuntando al **nodo directo** del item (los campos `d1`/`d2` y `dir` de su propia metadata) en vez de pasar por el salto de `/download/`. Medido sobre el mismo archivo: 2,08 s → **0,76 s** en el primer arranque y 1,33 s → **0,46 s** en los siguientes. También acelera cada avance dentro del tema y las descargas.
- **Sin cuentas, sin sesión y sin gateway**: Internet Archive sigue dando FLAC real de catálogo abierto, y toda la mejora es interna (no pide nada al usuario).

### 🔍 Verificado contra el servicio real
Estos números salen de pruebas contra archive.org, no de estimaciones: búsqueda repetida 0 ms (caché), resolución de stream repetida 0-1 ms, audio con rangos por byte correctos (`HTTP 206`) y ~7,5-9 MB/s de transferencia — de sobra para un FLAC.

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
- **Internet Archive searches are 5-8x faster**: item metadata is now read sequentially. archive.org throttles burst requests (measured: 8 items took 2.5 s one by one versus 7.9 s with 4 in parallel), so a full search dropped from 8-14 s to 1.6-4.2 s. It also stops as soon as it has enough tracks and caps how many items it reads.
- **Internet Archive now finds the song, not an unrelated collection**: it searches the item title first as a phrase and only falls back to free text (which also matches descriptions, and that's why it returned other records). "Miles Davis Kind of Blue" went from returning strangers to returning the right album.
- **Internet Archive audio starts ~3x faster**: URLs now point at the item's **direct node** (the `d1`/`d2` and `dir` fields from its own metadata) instead of going through the `/download/` redirect. Measured on the same file: 2.08 s → **0.76 s** on first start and 1.33 s → **0.46 s** afterwards. It also speeds up every seek and every download.
- **No account, no session, no gateway**: Internet Archive still serves real FLAC from an open catalog, and the whole improvement is internal (it asks the user for nothing).

### 🔍 Verified against the live service
These numbers come from tests against archive.org, not estimates: repeat search 0 ms (cache), repeat stream resolution 0-1 ms, audio with correct byte ranges (`HTTP 206`) and ~7.5-9 MB/s throughput — plenty for FLAC.

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