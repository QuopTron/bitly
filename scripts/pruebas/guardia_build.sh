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
echo "== 1) Ningún workflow ni script de build compila Go con un -ldflags fijo =="
# Un -ldflags escrito a mano significa "este build no consulta al helper": es
# exactamente la regresión que dejó a la 0.9.28 sin pool y sin registro.
fijos=$(grep -rn 'ldflags="-s -w"\|ldflags="-s -w ' "$WORKFLOWS" 2>/dev/null || true)
if [ -z "$fijos" ]; then
  ok "todos los workflows usan \$QOBUZ_LDFLAGS (o el helper), ninguno tiene el -ldflags a mano"
else
  echo "$fijos" | while IFS= read -r linea; do echo "         $linea"; done
  falla "hay un -ldflags fijo: usá -ldflags=\"\$QOBUZ_LDFLAGS\" y sourceá $HELPER antes"
fi

# Mismo criterio para los scripts locales: `build_windows_release.sh` (el que
# arma el instalador) compilaba el backend con un `-ldflags="-s -w"` pelado, y
# guardia_build.sh solo miraba los workflows, así que nadie lo veía.
# El patrón exige que el ldflags vaya DENTRO de un `go build` / `gomobile bind`:
# los propios chequeos de este archivo y de build.sh contienen ese literal en un
# grep, y marcarlos sería un falso positivo.
SCRIPTS_BUILD="go_backend/build.sh go_backend/build_all.sh scripts/build scripts/release"
fijos_scripts=$(grep -rnE '(go build|gomobile bind).*ldflags="-s -w' $SCRIPTS_BUILD 2>/dev/null \
  | grep -vE '^[^:]*:[0-9]+:[[:space:]]*#' || true)
if [ -z "$fijos_scripts" ]; then
  ok "los scripts de build (incluye el instalador de Windows) usan \$QOBUZ_LDFLAGS"
else
  echo "$fijos_scripts" | while IFS= read -r linea; do echo "         $linea"; done
  falla "un script de build compila Go con -ldflags fijo: sourceá $HELPER y pasá \$QOBUZ_LDFLAGS"
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
    if echo "$bloque" | grep -vE '^[[:space:]]*#' | grep -cE 'go build .*cmd/server|gomobile bind' \
       | grep -qv '^0$'; then
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
echo "== 2b) Todo script de build que compila Go sourcea el helper =="
# Los workflows se cubren arriba; acá van los scripts locales. La lista es
# finita a propósito: recorrer todo repo/ encontraría a este guardia (que
# nombra el helper en sus comentarios) y a embed_xcode.sh, que solo ECHOEA el
# comando de gomobile para que lo corra el usuario.
for sh in go_backend/build.sh go_backend/build_all.sh scripts/build/*.sh scripts/release/*.sh; do
  [ -f "$sh" ] || continue
  # Ignoran comentarios y los echo/info/warn de ayuda.
  # Se usa `grep -c` y no `grep -q`: con `set -o pipefail`, el -q corta el
  # pipe en cuanto encuentra la 1ª coincidencia y el grep de la izquierda
  # muere con SIGPIPE (141) → el pipe entero da "falso" y este chequeo se
  # caía en silencio JUSTO para build_all.sh, que era uno de los que había
  # que vigilar. Sin -q, ambos greps leen todo y el código es determinista.
  if [ "$(grep -vE '^[[:space:]]*(#|echo|info|warn)' "$sh" | grep -cE '(go build|gomobile bind)')" -gt 0 ]; then
    if grep -q 'qobuz_inyeccion' "$sh" && grep -q '\$QOBUZ_LDFLAGS' "$sh"; then
      ok "$(basename "$sh") sourcea el helper y usa \$QOBUZ_LDFLAGS"
    else
      falla "$sh compila Go sin sourcear $HELPER ni usar \$QOBUZ_LDFLAGS"
    fi
  fi
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
echo "== 4) Los builds locales (build.sh y build_all.sh) también inyectan =="
# build_all.sh compilaba AAR, EXE y los 6 targets desktop sin tocar el helper:
# era la ruta de build "grande" y salía justamente la que no inyectaba.
for sh in go_backend/build.sh go_backend/build_all.sh; do
  if grep -q 'source "\$INYECCION"' "$sh" && grep -q '\$QOBUZ_LDFLAGS' "$sh"; then
    ok "$(basename "$sh") sourcea el helper y usa \$QOBUZ_LDFLAGS"
  else
    falla "$(basename "$sh") no sourcea el helper o no usa \$QOBUZ_LDFLAGS"
  fi
  if grep -nE '(go build|gomobile bind).*ldflags="-s -w' "$sh" >/dev/null; then
    falla "$(basename "$sh") todavía tiene un -ldflags fijo"
  else
    ok "$(basename "$sh") sin -ldflags fijo"
  fi
done

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
echo "== 6) Cada -X de los builds apunta a un símbolo que existe =="
# `go build -ldflags="-X paquete.Var=valor"` NO falla si el símbolo no existe:
# lo ignora. Sin esta comprobación, renombrar una variable se lleva puesta la
# inyección sin que nadie se entere hasta ver un binario sin pool.
# Se leen el helper y los scripts de build: build.sh/build_all.sh además
# inyectan la versión (`-X internal/core.Version=…`), y ese -X también puede
# romperse en silencio.
# En el helper el target se escribe con la variable: -X $MODULO/pkg.Var=valor.
mapfile -t objetivos < <(grep -hoE '\-X [^ =]+=' "$HELPER" go_backend/build.sh go_backend/build_all.sh 2>/dev/null \
  | sed 's/^-X //; s/=$//' \
  | sed 's#^\$MODULO/#RAIZ_MODULO/#' \
  | sed "s#^RAIZ_MODULO/#$MODULO/#" \
  | sort -u)
if [ "${#objetivos[@]}" -eq 0 ]; then
  falla "no encontré ni un -X en $HELPER ni en los scripts de build (¿cambió de formato?)"
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
  # Dos formas: `var X = "…"` al paquete, o dentro de un bloque `var ( … )`
  # (indented). La segunda acepta también una asignación dentro de una
  # función con el mismo nombre: preferimos un falso positivo a dejar pasar
  # un rename, que sería fallar en silencio.
  if grep -rqE "^var $var[[:space:]]*=|^[[:space:]]+$var[[:space:]]*=" "$dir"/*.go; then
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
