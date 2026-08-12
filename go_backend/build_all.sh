#!/bin/bash
# build_all.sh — Build go_backend completo: tests + vet + AAR + EXE + docs
# Uso:
#   ./build_all.sh              # Purga outputs previos, corre tests/vet, compila todo
#   ./build_all.sh quick        # Solo build (salta tests si ya pasaron)
#   ./build_all.sh aar          # Solo Android AAR
#   ./build_all.sh exe          # Solo Windows EXE
#   ./build_all.sh desktop      # EXE + Linux + macOS
#   ./build_all.sh test         # Solo tests + vet
#
# Requisitos:
#   - Go 1.21+
#   - gomobile: go install golang.org/x/mobile/cmd/gomobile@latest
#   - Android NDK: $ANDROID_NDK_HOME o $ANDROID_HOME/ndk/
#   - Linux builds requieren cross-compile (CGO_ENABLED=0)
#
# Variables de entorno (opcionales):
#   AAR_OUTPUT    — ruta destino del AAR (def: ../bitly.aar)
#   EXE_OUTPUT    — ruta destino del EXE (def: ../bitly-backend-windows.exe)
#   ANDROID_NDK   — ruta al NDK si no está en PATH

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
AAR_OUTPUT="${AAR_OUTPUT:-"$ROOT/../bitly.aar"}"
EXE_OUTPUT="${EXE_OUTPUT:-"$ROOT/../bitly-backend-windows.exe"}"
VERSION="1.0.0"
DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)

# ─── Colores ────────────────────────────────────────────────
RED='\033[1;31m'; GREEN='\033[1;32m'
YELLOW='\033[1;33m'; CYAN='\033[1;36m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }

# ─── Step printer ───────────────────────────────────────────
step() {
    local num=$1; shift
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  [$num] $*${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
}

# ─── 1. Tests ───────────────────────────────────────────────
run_tests() {
    step "1/5" "Ejecutando tests..."
    cd "$ROOT"

    info "go vet ./... — Verificando código..."
    if go vet ./... 2>&1; then
        ok "go vet: sin errores"
    else
        fail "go vet encontró errores. Revisá arriba."
    fi

    info "go test ./... — Ejecutando suite de tests..."
    local start; start=$(date +%s)
    if go test ./... -count=1 -timeout=120s 2>&1; then
        local elapsed=$(( $(date +%s) - start ))
        ok "Tests: TODOS PASARON (${elapsed}s)"
    else
        fail "Tests fallaron. Revisá arriba."
    fi
}

# ─── 2. Build nativo (verifica que compile) ─────────────────
build_native() {
    step "2/5" "Build nativo (go build ./...)..."

    cd "$ROOT"
    if go build ./... 2>&1; then
        ok "Build nativo: todo compila"
    else
        fail "Build nativo falló"
    fi
}

# ─── 3. AAR Android ─────────────────────────────────────────
build_aar() {
    step "3/5" "Build AAR Android..."

    cd "$ROOT"

    # Verificar gomobile
    if ! command -v gomobile &>/dev/null; then
        fail "gomobile no instalado. Ejecutá:\n  go install golang.org/x/mobile/cmd/gomobile@latest\n  gomobile init"
    fi

    # Verificar NDK
    local ndk="${ANDROID_NDK:-${ANDROID_NDK_HOME:-}}"
    if [ -z "$ndk" ] && [ -n "${ANDROID_HOME:-}" ]; then
        ndk=$(ls -d "$ANDROID_HOME/ndk/"* 2>/dev/null | sort -V | tail -1 || true)
    fi
    if [ -z "$ndk" ]; then
        warn "ANDROID_NDK no configurado. Intentando build sin NDK explícito..."
    else
        export ANDROID_NDK_HOME="$ndk"
        info "NDK: $ndk"
    fi

    # Inicializar gomobile si hace falta
    gomobile init 2>/dev/null || true

    local aar_dir; aar_dir=$(dirname "$AAR_OUTPUT")
    mkdir -p "$aar_dir"

    # OJO: target=android incluye TODAS las ABIs (arm, arm64, x86, x86_64).
    # Si se limita a arm/arm64, el emulador x86_64 crashea con
    # 'libgojni.so not found' (UnsatisfiedLinkError) porque el APK no trae la lib.
    info "gomobile bind — target: android (arm, arm64, x86, x86_64)..."
    gomobile bind \
        -target="android" \
        -androidapi 24 \
        -ldflags="-s -w -X main.version=$VERSION -X main.buildDate=$DATE" \
        -o "$AAR_OUTPUT" \
        ./

    if [ -f "$AAR_OUTPUT" ]; then
        local size; size=$(du -h "$AAR_OUTPUT" | cut -f1)
        ok "AAR: $AAR_OUTPUT ($size)"
    else
        fail "AAR no se creó en $AAR_OUTPUT"
    fi

    # gradle lee el AAR desde android/app/libs/bitly.aar (implementation(files("libs/bitly.aar"))).
    # Copiar ahí para que el flujo documentado produzca siempre un APK consistente.
    local android_libs="$ROOT/../android/app/libs"
    if [ -d "$android_libs" ]; then
        cp "$AAR_OUTPUT" "$android_libs/bitly.aar"
        ok "AAR copiado a: $android_libs/bitly.aar"
    else
        warn "No existe $android_libs — saltando copia a android/app/libs (solo se dejó $AAR_OUTPUT)"
    fi
}

# ─── 4. EXE Windows ─────────────────────────────────────────
build_exe() {
    step "4/5" "Build EXE Windows..."

    cd "$ROOT"

    local exe_dir; exe_dir=$(dirname "$EXE_OUTPUT")
    mkdir -p "$exe_dir"

    info "go build — GOOS=windows GOARCH=amd64..."
    GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build \
        -ldflags="-s -w -X main.version=$VERSION -X main.buildDate=$DATE" \
        -o "$EXE_OUTPUT" \
        ./cmd/server/

    if [ -f "$EXE_OUTPUT" ]; then
        local size; size=$(du -h "$EXE_OUTPUT" | cut -f1)
        ok "EXE: $EXE_OUTPUT ($size)"
    else
        fail "EXE no se creó en $EXE_OUTPUT"
    fi
}

# ─── 5. Desktop multiplataforma ─────────────────────────────
build_desktop_all() {
    step "5/5" "Build desktop multiplataforma..."

    cd "$ROOT"
    local out_dir="$ROOT/build"
    mkdir -p "$out_dir"

    local targets=(
        "windows,amd64,.exe"
        "windows,arm64,.exe"
        "darwin,amd64,"
        "darwin,arm64,"
        "linux,amd64,"
        "linux,arm64,"
    )

    for target in "${targets[@]}"; do
        IFS=',' read -r os arch suffix <<< "$target"
        local output="$out_dir/bitly-backend-$os-$arch$suffix"
        info "  $os/$arch → $output"

        if GOOS="$os" GOARCH="$arch" CGO_ENABLED=0 go build \
            -ldflags="-s -w -X main.version=$VERSION -X main.buildDate=$DATE" \
            -o "$output" ./cmd/server/ 2>/dev/null; then
            local size; size=$(du -h "$output" | cut -f1)
            ok "  $os/$arch ($size)"
        else
            warn "  $os/$arch falló (puede requerir toolchain cruzada)"
        fi
    done

    echo ""
    info "Outputs en: $out_dir"
    ls -lh "$out_dir"/
}

# ─── Main ───────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   🏗️  BITLY GO BACKEND — BUILD COMPLETO        ║${NC}"
    echo -e "${CYAN}║   ${VERSION} — ${DATE}                ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"

    cd "$ROOT"

    case "${1:-full}" in
        quick)
            warn "Modo quick: saltando tests..."
            build_native
            build_aar
            build_exe
            ;;
        aar)
            build_aar
            ;;
        exe)
            build_exe
            ;;
        desktop)
            build_desktop_all
            ;;
        test)
            run_tests
            ;;
        full|*)
            run_tests
            build_native
            build_aar
            build_exe
            ;;
    esac

    # ─── Resumen final ─────────────────────────────────────
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ✅ BUILD COMPLETO                             ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"

    [ -f "$AAR_OUTPUT" ] && echo "  📦 AAR:  $(du -h "$AAR_OUTPUT" | cut -f1) — $AAR_OUTPUT"
    [ -f "$EXE_OUTPUT" ] && echo "  🪟 EXE:  $(du -h "$EXE_OUTPUT" | cut -f1) — $EXE_OUTPUT"

    echo ""
    echo -e "  ${CYAN}Próximos pasos sugeridos:${NC}"
    echo "    ./build_all.sh test        # Solo tests + vet"
    echo "    ./build_all.sh quick       # Build sin tests"
    echo "    ./build_all.sh desktop     # Todas las plataformas desktop"
    echo ""
}

main "$@"
