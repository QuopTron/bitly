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

  NOTAS_ES=$(cat <<'EOF'
## 🎵 Bitly v0.9.10 — Android + PC

### ✨ Novedades
- **Verificación Cloudflare corregida en PC**: el modal del captcha ahora se cierra solo al verificar (el grant vuelve por el parser tolerante, igual que en Android).
- **Detector de versiones multiplataforma**: ahora funciona en Android y Windows y elige el archivo correcto según la arquitectura (arm64 / armv7 / x86_64 en Android, x64/arm64 en Windows).
- **Actualización silenciosa de extensiones**: al arrancar, las extensiones del registro empaquetado se actualizan solas si la versión instalada quedó vieja.
- **Detección de fuentes verificadas en búsquedas**: las búsquedas detectan las keys de las fuentes verificadas en ambas plataformas.

### 🐛 Correcciones
- Muteo intermitente al cambiar de canción (repetir / repetir una vez / shuffle).
- Backend Go cerrado correctamente al cerrar la app en PC (en celular sigue en segundo plano).
- Diseños de PC: grids más amplios en Feed, Búsqueda y Mi Espacio.
- Icono correcto de la app en Windows.

### ⬇️ Descargas
- Android: `app-arm64-v8a-release.apk` / `app-armeabi-v7a-release.apk` / `app-x86_64-release.apk`
- Windows: `Bitly-Setup-0.9.10.exe`
EOF
)
  NOTAS_EN=$(cat <<'EOF'

---

## 🎵 Bitly v0.9.10 — Android + PC

### ✨ Highlights
- **Cloudflare verification fixed on PC**: the captcha modal now closes by itself after verifying (the grant returns through the tolerant parser, same as Android).
- **Cross-platform version detector**: now works on Android and Windows and picks the right file for your architecture (arm64/armv7/x86_64 on Android, x64/arm64 on Windows).
- **Silent extension updates**: on startup, bundled extensions update themselves if the installed copy is outdated.
- **Verified-source detection in search**: searches detect the keys of verified sources on both platforms.

### 🐛 Fixes
- Intermittent muting when switching tracks (repeat / repeat one / shuffle).
- Go backend now closes when closing the app on PC (keeps running in background on mobile).
- Wider PC grids on Feed, Search and My Space.
- Correct app icon on Windows.

### ⬇️ Downloads
- Android: `app-arm64-v8a-release.apk` / `app-armeabi-v7a-release.apk` / `app-x86_64-release.apk`
- Windows: `Bitly-Setup-0.9.10.exe`
EOF
)

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