#!/bin/bash
# build.sh — Build go_backend for all platforms
# Usage:
#   ./build.sh              # Build for current platform
#   ./build.sh all          # Build all platforms
#   ./build.sh aar          # Android AAR only
#   ./build.sh desktop      # Desktop binaries only
#
# Requires:
#   - Go 1.21+
#   - gomobile (for AAR): go install golang.org/x/mobile/cmd/gomobile@latest
#   - Android NDK (for AAR): set ANDROID_NDK_HOME

set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/build"
VERSION="1.0.0"
DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mkdir -p "$BUILD_DIR"

info()  { echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]\033[0m $*"; }
fail()  { echo -e "\033[1;31m[FAIL]\033[0m $*"; exit 1; }

# Detect Go
GOOS="${GOOS:-$(go env GOOS)}"
GOARCH="${GOARCH:-$(go env GOARCH)}"

build_desktop() {
    local os="$1" arch="$2" suffix="$3"
    local output="$BUILD_DIR/bitly-backend-$os-$arch$suffix"
    info "Building desktop: $os/$arch → $output"

    GOOS="$os" GOARCH="$arch" CGO_ENABLED=0 go build \
        -ldflags="-s -w -X main.version=$VERSION -X main.buildDate=$DATE" \
        -o "$output" ./cmd/server/

    if [ -f "$output" ]; then
        ok "Desktop binary: $output ($(du -h "$output" | cut -f1))"
    else
        fail "Desktop binary not created"
    fi
}

build_aar() {
    info "Building Android AAR..."

    if ! command -v gomobile &>/dev/null; then
        fail "gomobile not found. Install: go install golang.org/x/mobile/cmd/gomobile@latest"
    fi

    # Initialize gomobile if needed
    gomobile init 2>/dev/null || true

    # Build for arm64 and arm (armeabi-v7a)
    gomobile bind \
        -target="android/arm,android/arm64" \
        -androidapi 24 \
        -ldflags="-s -w" \
        -o "$BUILD_DIR/bitly-backend.aar" \
        ./

    if [ -f "$BUILD_DIR/bitly-backend.aar" ]; then
        ok "AAR: $BUILD_DIR/bitly-backend.aar ($(du -h "$BUILD_DIR/bitly-backend.aar" | cut -f1))"
    else
        fail "AAR not created"
    fi
}

build_ios() {
    info "Building iOS XCFramework..."
    if ! command -v gomobile &>/dev/null; then
        fail "gomobile not found"
    fi
    gomobile bind \
        -target="ios" \
        -ldflags="-s -w" \
        -o "$BUILD_DIR/BitlyBackend.xcframework" \
        ./
    ok "iOS: $BUILD_DIR/BitlyBackend.xcframework"
}

# Parse command
case "${1:-current}" in
    all)
        build_desktop "windows" "amd64" ".exe"
        build_desktop "windows" "arm64" ".exe"
        build_desktop "darwin" "amd64" ""
        build_desktop "darwin" "arm64" ""
        build_desktop "linux"   "amd64" ""
        build_desktop "linux"   "arm64" ""
        build_aar
        ;;
    aar)
        build_aar
        ;;
    ios)
        build_ios
        ;;
    desktop)
        build_desktop "$GOOS" "$GOARCH" "$( [ \"$GOOS\" = windows ] && echo '.exe' || echo '' )"
        build_desktop "windows" "amd64" ".exe"
        build_desktop "darwin" "amd64" ""
        build_desktop "darwin" "arm64" ""
        build_desktop "linux" "amd64" ""
        build_desktop "linux" "arm64" ""
        ;;
    current|*)
        build_desktop "$GOOS" "$GOARCH" "$( [ \"$GOOS\" = windows ] && echo '.exe' || echo '' )"
        ;;
esac

# Also build a native .go build test
info "Running go vet..."
go vet ./... || fail "go vet failed"

info "Running go build..."
go build ./... || fail "go build failed"

ok "Build complete. Outputs in: $BUILD_DIR"
ls -lh "$BUILD_DIR"/
