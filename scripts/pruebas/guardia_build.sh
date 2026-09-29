#!/usr/bin/env bash
#
# guardia_build.sh — que ningún binario salga sin la config del Worker.
#
# Por qué existe: el repo NO escribe las URLs del Worker en el fuente (llevan el
# secreto en la ruta y el repo es público); el build las INYECTA con -ldflags.
# Eso tiene TRES formas conocidas de romperse en silencio:
#
#   1. un `-ldflags="-s -w"` pelado que nadie actualizó → el binario sale sin
#      pool de Qobuz y sin registro de códigos premium (los códigos validan pero
#      NO se marcan como usados: un código filtrado sirve para siempre);
#   2. un paso que compila Go y no sourcea el helper (mismo resultado silencioso);
#   3. un `-X paquete.Variable` cuyo símbolo ya no existe: Go NO falla, ignora el
#      -X y el binario sale sin la URL. Basta un rename para perder la inyección
#      entera sin que nada avise.
#
# También comprueba lo contrario: que los workflows de DESARROLLO no lleven los
# secretos del Worker (sus artefactos se bajan del repo, que todavía es público)
# y que el helper no se caiga cuando a `qobuz-worker.env` le falta una clave.
#
# Uso: bash scripts/pruebas/guardia_build.sh

set -uo pipefail
cd "$(dirname "$0")/../.."

WORKFLOWS=".github/workflows"
HELPER="scripts/dev/qobuz_inyeccion.sh"
MODULO="github.com/zarz/bitly/go_backend"
fallas=0

ok() { echo "  ok    $1"; }
falla() {
  echo "  FALLA $1"
  fallas=$((fallas + 1))
}

echo
echo "== 1) Ningún workflow compila Go con un -ldflags fijo =="
# Un -ldflags escrito a mano significa "este build no consulta al helper": es
# exactamente la regresión que dejó a la 0.9.28 sin pool y sin registro.
fijos=$(grep -rn 'ldflags="-s -w"\|ldflags="-s -w ' "$WORKFLOWS" 2>/dev/null || true)
if [ -z "$fijos" ]; then
  ok "todos los builds usan \$QOBUZ_LDFLAGS (o el helper), ninguno tiene el -ldflags a mano"
else
  echo "$fijos" | while IFS= read -r linea; do echo "         $linea"; done
  falla "hay un -ldflags fijo: usá -ldflags=\"\$QOBUZ_LDFLAGS\" y sourceá $HELPER antes"
fi

echo
echo "== 2) Todo paso que compila Go sourcea el helper =="
for wf in "$WORKFLOWS"/*.yml; do
  # Cada "step" arranca con "      - name:" y se juzga el bloque COMPLETO (un
  # `cd go_backend` antes del source no esconde nada). Los bloques se separan con
  # el byte 0x1f y se leen con `read -d`, no línea por línea: si no, cada línea
  # parecería un paso y todo daría FALLA.
  while IFS= read -r -d $'\x1f' bloque; do
    # Se ignoran las líneas comentadas: los headers de los workflows nombran
    # `gomobile bind` para explicar qué hace el workflow, y eso no compila nada.
    if echo "$bloque" | grep -vE '^[[:space:]]*#' | grep -qE 'go build .*cmd/server|gomobile bind'; then
      nombre=$(echo "$bloque" | grep -m1 -- '- name:' | sed 's/.*- name: *//')
      if echo "$bloque" | grep -q "source $HELPER"; then
        ok "$(basename "$wf"): $nombre"
      else
        falla "$(basename "$wf"): '$nombre' compila Go sin sourcear $HELPER"
      fi
    fi
  done < <(awk '/^      - name:/{if (b != "") printf "%s%c", b, 31; b = ""} {b = b $0 "\n"} END {if (b != "") printf "%s%c", b, 31}' "$wf")
done

echo
echo "== 3) Los workflows de RELEASE inyectan las 4 URLs; los de desarrollo NO =="
for wf in release.yml release-macos.yml; do
  for clave in QOBUZ_POOL_URL QOBUZ_KEYS_URL QOBUZ_API_BASE PREMIUM_REGISTRO_URL; do
    if grep -q "secrets\.$clave" "$WORKFLOWS/$wf"; then
      ok "$wf: $clave desde secrets"
    else
      falla "$wf no pasa $clave: ese binario saldría sin la config del Worker"
    fi
  done
done
# build.yml corre en cada push y sus artefactos se descargan del repo, que es
# público: si mañana alguien copia el env de release.yml acá, esto lo caza.
if grep -qE "QOBUZ_POOL_URL|PREMIUM_REGISTRO_URL|QOBUZ_KEYS_URL|QOBUZ_API_BASE" "$WORKFLOWS/build.yml"; then
  falla "build.yml (CI de cada push) lleva secretos del Worker: sus artefactos se bajan del repo público"
else
  ok "build.yml no lleva los secretos del Worker (a propósito: sus artefactos son públicos)"
fi

echo
echo "== 4) El build local (go_backend/build.sh) también inyecta =="
if grep -q 'source "\$INYECCION"' go_backend/build.sh && grep -q '\$QOBUZ_LDFLAGS' go_backend/build.sh; then
  ok "build.sh sourcea el helper y usa \$QOBUZ_LDFLAGS"
else
  falla "build.sh no sourcea el helper o no usa \$QOBUZ_LDFLAGS"
fi
if grep -q 'ldflags="-s -w \|ldflags="-s -w"' go_backend/build.sh; then
  falla "build.sh todavía tiene un -ldflags fijo"
else
  ok "build.sh sin -ldflags fijo"
fi

echo
echo "== 5) El helper no se cae cuando falta una clave =="
# Leer qobuz-worker.env con `grep` sin match devuelve 1: si el helper se SOURCEA
# desde un script con `set -e -o pipefail` (build.sh), eso tumbaba el build entero
# y sin ningún mensaje. Ya pasó una vez.
# Se buscan las DOS cosas en la MISMA línea y sin contar comentarios: este mismo
# archivo explica el `|| true` en un comentario, así que un grep suelto daría
# verde con la guarda borrada (falso negativo que ya tuvo una versión de esto).
guarda=$(grep -vE '^[[:space:]]*#' "$HELPER" | grep -F 'grep -E' | grep -F '|| true' || true)
if [ -n "$guarda" ]; then
  ok "el grep de las claves está protegido con '|| true'"
else
  falla "$HELPER lee el .env sin '|| true': con set -e/pipefail se cae en silencio si falta una clave"
fi

echo
echo "== 6) Cada -X del helper apunta a un símbolo que existe =="
# `go build -ldflags="-X paquete.Var=valor"` NO falla si el símbolo no existe:
# lo ignora. Sin esta comprobación, renombrar una variable se lleva puesta la
# inyección sin que nadie se entere hasta ver un binario sin pool.
# En el helper el target se escribe con la variable: -X $MODULO/pkg.Var=valor.
mapfile -t objetivos < <(grep -oE '\-X [^ =]+=' "$HELPER" \
  | sed 's/^-X //; s/=$//' \
  | sed 's#^\$MODULO/#RAIZ_MODULO/#' \
  | sed "s#^RAIZ_MODULO/#$MODULO/#" \
  | sort -u)
if [ "${#objetivos[@]}" -eq 0 ]; then
  falla "no encontré ni un -X en $HELPER (¿cambió de formato?)"
fi
for obj in "${objetivos[@]}"; do
  pkg="${obj%.*}"
  var="${obj##*.}"
  pkg="${pkg#"$MODULO"/}"
  dir="go_backend/$pkg"
  if [ ! -d "$dir" ]; then
    falla "-X $obj: no existe el paquete $dir"
    continue
  fi
  if grep -rqE "^var $var = " "$dir"/*.go; then
    ok "-X $pkg.$var → var $var encontrada"
  else
    falla "-X $pkg.$var no tiene 'var $var' en $dir: Go lo ignora en silencio y el binario sale SIN la URL"
  fi
done

echo
if [ "$fallas" -eq 0 ]; then
  echo "TODO OK — ningún build sale sin la config del Worker."
  exit 0
fi
echo "$fallas FALLA(S) — hay builds que saldrían sin pool/registro del Worker."
exit 1
