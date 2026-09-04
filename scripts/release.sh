#!/usr/bin/env bash
#
# release.sh — Lanza una nueva versión (0.0.x) y publica el APK vía GitHub
# Actions + GitHub Release (alternativa al Play Store).
#
# Uso:
#   bash scripts/release.sh                 # sube +0.0.1 (patch)
#   bash scripts/release.sh 0.9.5           # fija una versión exacta
#   bash scripts/release.sh --emulator      # además genera el APK x86_64
#
# Qué hace:
#   1. Lee la versión actual de pubspec.yaml (formato X.Y.Z+CODE).
#   2. Sube la versión (patch por defecto) y el versionCode en +1.
#   3. Commitea el bump, crea el tag vX.Y.Z y hace push (rama + tag).
#   4. El workflow .github/workflows/release.yml compila el APK y crea la
#      GitHub Release automáticamente con el binario adjunto.
#
# Nota: el tag vX.Y.Z es lo que dispara el workflow de release. El versionCode
# de Android (el +N) se usa para que las instalaciones "encima" se reconozcan
# como actualización.

set -euo pipefail

cd "$(dirname "$0")/.."

INCLUDE_EMULATOR="false"
if [[ "${1:-}" == "--emulator" ]]; then
  INCLUDE_EMULATOR="true"
  shift
fi

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

# Verifica que no exista el tag
if git rev-parse "v${NEW_VERSION}" >/dev/null 2>&1; then
  echo "::error::El tag v${NEW_VERSION} ya existe" >&2
  exit 1
fi

# Bump en pubspec.yaml (compatible con CRLF de Windows)
sed -i "s/^version: .*/version: ${NEW_VERSION}+${CODE}/" pubspec.yaml

echo "Bump aplicado: version: ${NEW_VERSION}+${CODE}"
git diff --stat pubspec.yaml

git add pubspec.yaml
git commit -m "release: v${NEW_VERSION} (${NEW_VERSION}+${CODE})"
git tag "v${NEW_VERSION}"
git push origin main
git push origin "v${NEW_VERSION}"

echo ""
echo "✅ Tag v${NEW_VERSION} publicado. GitHub Actions está compilando el APK."
if [[ "$INCLUDE_EMULATOR" == "true" ]]; then
  echo "   (incluye variante x86_64 para emulador)"
fi
echo "   Revisa el progreso en: https://github.com/QuopTron/bitly/actions"
echo "   Cuando termine, el APK estará en: https://github.com/QuopTron/bitly/releases"