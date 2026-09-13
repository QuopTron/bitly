#!/usr/bin/env bash
# ============================================================================
# mapa_flutter.sh — Mapea TODO el Flutter: líneas, estructura, llamadas al
#                   backend y lógica que podría vivir en Go.
# ============================================================================
# Para qué sirve:
#   1. Inventario completo: líneas por carpeta y por archivo.
#   2. God files (archivos gigantes que conviene partir).
#   3. TODOS los métodos RPC que Flutter llama, con el patrón exacto:
#        • rpcCall('...') crudo  → contrato NO tipado (riesgo de typos)
#        • método tipado en mixin → contrato tipado (bien)
#   4. Detección de lógica que podría moverse a Go (premium, niveles,
#      descargas, dedup, cifrado...) — para decidir el reparto correcto.
#
# Cómo se usa (desde la raíz del repo):
#   bash lib-nuevo/scripts/mapa_flutter.sh            → informe completo
#   bash lib-nuevo/scripts/mapa_flutter.sh --arbol    → líneas por carpeta+archivo
#   bash lib-nuevo/scripts/mapa_flutter.sh --rpc      → todos los RPC que llama
#   bash lib-nuevo/scripts/mapa_flutter.sh --a-go     → lógica candidata a Go
#   bash lib-nuevo/scripts/mapa_flutter.sh --ayuda    → esta ayuda
# ============================================================================

set -u

LIB_DIR="lib"
MODO="completo"

for arg in "$@"; do
  case "$arg" in
    --arbol) MODO="arbol" ;;
    --rpc)   MODO="rpc" ;;
    --a-go)  MODO="a-go" ;;
    --ayuda|-h|--help) MODO="ayuda" ;;
  esac
done

if [ "$MODO" = "ayuda" ]; then
  sed -n '1,30p' "$0" | grep -E "^# " | sed 's/^# \{0,1\}//'
  exit 0
fi

[ -d "$LIB_DIR" ] || { echo "❌ No encuentro $LIB_DIR — corre desde la raíz del repo."; exit 1; }

echo "═══════════════════════════════════════════════════════════════"
echo "  MAPA DEL FLUTTER — estructura + puente con Go"
echo "═══════════════════════════════════════════════════════════════"

# ── 1) Resumen general ─────────────────────────────────────────────────────
TOTAL_ARCHIVOS=$(find "$LIB_DIR" -name "*.dart" | wc -l)
TOTAL_LINEAS=$(find "$LIB_DIR" -name "*.dart" -exec cat {} + | wc -l)
GENERADOS=$(find "$LIB_DIR" -name "*.g.dart" | wc -l)
GENERADOS_LINEAS=$(find "$LIB_DIR" -name "*.g.dart" -exec cat {} + | wc -l)
CODIGO_LINEAS=$((TOTAL_LINEAS - GENERADOS_LINEAS))

echo "  Archivos .dart        : $TOTAL_ARCHIVOS"
echo "  Líneas totales        : $TOTAL_LINEAS"
echo "  └─ generados (.g.dart): $GENERADOS archivos / $GENERADOS_LINEAS líneas (~$(echo "scale=0; $GENERADOS_LINEAS * 100 / $TOTAL_LINEAS" | bc 2>/dev/null || echo "?")%)"
echo "  └─ escritos a mano    : $CODIGO_LINEAS líneas"
echo ""

# ── 2) God files (>400 líneas) ─────────────────────────────────────────────
if [ "$MODO" = "completo" ] || [ "$MODO" = "arbol" ]; then
  echo "── GOD FILES (>400 líneas — candidatos a partir) ──────────────"
  find "$LIB_DIR" -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + \
    | sort -rn | awk '$1 > 400 && $2 != "total" {printf "  %6s  %s\n", $1, $2}' | head -20
  echo ""
fi

# ── 3) Líneas por carpeta ──────────────────────────────────────────────────
if [ "$MODO" = "completo" ] || [ "$MODO" = "arbol" ]; then
  echo "── LÍNEAS POR CARPETA ──────────────────────────────────────────"
  find "$LIB_DIR" -type d | sort | while read -r d; do
    n=$(find "$d" -maxdepth 1 -name "*.dart" -exec cat {} + 2>/dev/null | wc -l)
    [ "$n" -gt 0 ] && printf "  %6s  %s\n" "$n" "${d#./}"
  done | sort -rn
  echo ""
fi

# ── 4) Todos los RPC que llama Flutter ─────────────────────────────────────
if [ "$MODO" = "completo" ] || [ "$MODO" = "rpc" ]; then
  echo "── MÉTODOS RPC QUE LLAMA FLUTTER ──────────────────────────────"
  echo ""

  # a) Vía contrato tipado (mixins) — los métodos declarados en backend_service.dart
  echo "▸ Declarados en backend_service.dart (contrato tipado, bien):"
  grep -oE "Future<[^>]+> [a-zA-Z]+\(" "$LIB_DIR/backend/rpc/backend_service.dart" \
    | grep -oE "[a-zA-Z]+\(" | tr -d '(' | sort -u | sed 's/^/    · /'
  echo ""

  # b) rpcCall('...') crudo — llamadas directas con string (riesgo de typo)
  echo "▸ rpcCall('...') crudo — contrato NO tipado (donde se cuelan los typos):"
  echo "    (método) ← llamado desde"
  grep -rn "rpcCall('" "$LIB_DIR" --include="*.dart" \
    | grep -oE "rpcCall\('[a-zA-Z]+'" \
    | sed "s/rpcCall('//;s/'//" | sort | uniq -c | sort -rn \
    | sed 's/^ *\([0-9]*\) \(.*\)/    \2 (×\1)/'
  echo ""

  # c) invokeMethod directo a nativos (fuera de rpcCall — canales propios)
  echo "▸ invokeMethod directo a canales nativos (Kotlin/Swift, no RPC):"
  grep -rhoE "invokeMethod<[^>]*>\('[a-zA-Z]+'|invokeMethod\('[a-zA-Z]+'" "$LIB_DIR" --include="*.dart" \
    | grep -oE "'[a-zA-Z]+'" | tr -d "'" | sort -u | sed 's/^/    · /'
  echo ""
fi

# ── 5) Lógica candidata a vivir en Go ──────────────────────────────────────
if [ "$MODO" = "completo" ] || [ "$MODO" = "a-go" ]; then
  echo "── LÓGICA QUE PODRÍA VIVIR EN GO (reparto correcto) ───────────"
  echo "  Regla: Go = cerebro (negocio), Flutter = cara (UI + dispositivo)."
  echo "  Estos archivos de Flutter contienen lógica de negocio duplicada"
  echo "  o mal ubicada — candidata a moverse a Go:"
  echo ""

  # Candidatos conocidos por su nombre
  for f in premium_service provider_credential_service download_cubit \
           playlist_generator_service scrobble_service verification_service; do
    archivo=$(find "$LIB_DIR" -name "$f.dart" 2>/dev/null | head -1)
    if [ -n "$archivo" ]; then
      lineas=$(wc -l < "$archivo")
      echo "  ⚠ $f.dart  ($lineas líneas)"
    fi
  done
  echo ""

  # Lógica de negocio detectada por patrones (cálculos que Go ya hace)
  echo "  Patrones de negocio encontrados en Flutter:"
  buscar_patron() {
    local nombre="$1" patron="$2"
    local total
    total=$(grep -rln "$patron" "$LIB_DIR" --include="*.dart" 2>/dev/null | wc -l)
    if [ "$total" -gt 0 ]; then
      echo "    · $nombre: $total archivos"
      grep -rln "$patron" "$LIB_DIR" --include="*.dart" 2>/dev/null \
        | head -4 | sed 's/^/        └ /'
    fi
  }
  buscar_patron "validación premium (HMAC/códigos)" "premium"
  buscar_patron "cálculo de niveles/estadísticas de usuario" "calculateLevel\|levelFor"
  buscar_patron "deduplicación de resultados (dedup)" "dedup"
  buscar_patron "descifrado/decrypt (debería ser Go)" "decrypt\|decipher"
  buscar_patron "firma/verificación (crypto)" "hmac\|signature"
  buscar_patron "estimación de tamaño de archivo (Go lo hace)" "estimateTrackFileSize\|estimateSize"
  echo ""

  # Fugas cruzadas: mismos conceptos en ambos lados
  echo "  Conceptos presentes en Go Y en Flutter (posible duplicación):"
  for concepto in "level" "premium" "dedup" "fingerprint" "scrobble" "rescue"; do
    go=$(grep -rln "$concepto" go_backend --include="*.go" 2>/dev/null | wc -l)
    fl=$(grep -rln "$concepto" "$LIB_DIR" --include="*.dart" 2>/dev/null | wc -l)
    if [ "$go" -gt 0 ] && [ "$fl" -gt 0 ]; then
      echo "    · '$concepto': Go ($go archivos) + Flutter ($fl archivos) ⚠"
    fi
  done
  echo ""
fi

# ── 6) Dependencias externas ───────────────────────────────────────────────
if [ "$MODO" = "completo" ]; then
  echo "── DEPENDENCIAS EXTERNAS (pubspec.yaml) ───────────────────────"
  if [ -f pubspec.yaml ]; then
    sed -n '/^dependencies:/,/^dev_dependencies:/p' pubspec.yaml \
      | grep -E "^\s{2}[a-z_0-9]+:" | sed 's/^/  /'
  fi
  echo ""
fi