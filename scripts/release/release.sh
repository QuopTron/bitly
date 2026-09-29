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
#      instalador de Windows (scripts/build/build_windows_release.sh).
#   3. Commitea el bump, crea el tag vX.Y.Z y hace push.
#   0. Con --upload, CHEQUEA el espejo ANTES de compilar (gh autenticado con
#      scope 'workflow', RELEASES_TOKEN configurado, repo público accesible):
#      así no se pierde un build entero por algo que se arregla en un minuto.
#   4. Crea la GitHub Release con notas en español (primario) e inglés.
#   5. Dispara el ESPEJO al repo PÚBLICO de releases: es lo que leen la app y
#      el sitio, así que las descargas aparecen ya y no en el cron de 6 h.
# Uso:
#   bash scripts/release/release.sh              # sube +0.0.1 (patch)
#   bash scripts/release/release.sh 0.9.10       # fija una versión exacta
#   bash scripts/release/release.sh --no-aar     # reusa el AAR Go ya compilado
#   bash scripts/release/release.sh 0.9.10 --upload   # publica y espeja ya
#
# Env opcional:
#   PERMITIR_SIN_REGISTRO=true   publica aunque falte PREMIUM_REGISTRO_URL
#                                (los códigos validan pero NO se marcan usados)
#
# Parte del flujo: release (Android + Windows).

set -euo pipefail

cd "$(dirname "$0")/../.."

HACER_WINDOWS="false"
SUBIR_RELEASE="false"
REHACER_AAR="true"
VERSION_ARG=""
for arg in "$@"; do
  case "$arg" in
    --windows) HACER_WINDOWS="true" ;;
    --upload) SUBIR_RELEASE="true" ;;
    --no-aar) REHACER_AAR="false" ;;
    --*) ;;
    *)
      # Un X.Y.Z suelto (en cualquier posición) fija la versión exacta. Antes
      # solo miraba $1, así que `release.sh --upload 0.9.10` ignoraba la
      # versión y subía el patch en vez de publicar la pedida.
      if [[ "$arg" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then VERSION_ARG="$arg"; fi
      ;;
  esac
done

# El repo del CÓDIGO (privado: ahí va la release "fuente") y el repo PÚBLICO al
# que el espejo copia los binarios. El público es el que leen la app
# (UpdateService.repoPublico) y el sitio: si cambia uno, tiene que cambiar
# también en lib/features/ajustes/update/base/update_service.dart.
REPO_CODIGO="QuopTron/bitly"
ESPEJO_REPO="QuopTron/bitly-releases"

# ── Chequeo de tokens embebidos ─────────────────────────────────────
# El APK y el .exe COMPILAN lib/config/secretos.dart: lo que esté ahí viaja
# adentro del binario, y estos binarios se publican en un repo PÚBLICO donde
# cualquiera los baja y los abre. Un PAT CLÁSICO (ghp_…) tiene acceso a TODOS
# los repos de la cuenta: si sale en un APK, hay que revocarlo enseguida.
#
# Pasó de verdad: el APK de la 0.9.28 (build LOCAL, con el secretos.dart del
# momento) salió con un ghp_… embebido y quedó descargable sin token. Por eso
# acá se corta ANTES de publicar, y el espejo tiene la misma barrera del lado
# del workflow (es el último paso antes de que el asset quede público).
PAT_CLASICO_RE='ghp_[A-Za-z0-9]{30,}'
# ── Inyección del Worker (pool de Qobuz + registro premium) ─────────────
# Las URLs del Worker llevan su secreto EN LA RUTA, así que no viven en el repo
# (es público): el build las inyecta con -ldflags desde qobuz-worker.env
# (gitignoreado) usando scripts/dev/qobuz_inyeccion.sh. Ojo con QUÉ significa
# que falte una:
#   · sin QOBUZ_POOL_URL: el binario sale sin pool de Qobuz (canal firmado
#     directo, sin rotación de ARLs) — molesto, pero la app funciona;
#   · sin PREMIUM_REGISTRO_URL: la app NO consulta el registro de códigos. Los
#     legacy VALIDAN igual (la firma/estructura es local), pero NO se marcan
#     como usados, que es justo lo que evita que un código compartido se reuse
#     para siempre. Por eso, al PUBLICAR (--upload) esto corta antes de
#     compilar (así no se pierde el build), y con PERMITIR_SIN_REGISTRO=true
#     se puede seguir igual a sabiendas.
# _http_codigo imprime SOLO el código HTTP de una URL (000 = no hubo respuesta:
# sin red, DNS, timeout). Nunca corta el script: un Worker caído es información,
# no un error del que llama.
_http_codigo() {
  local url="$1" codigo
  shift
  codigo="$(curl -s -o /dev/null -w '%{http_code}' --max-time 12 "$@" "$url" 2>/dev/null)" || true
  printf '%s' "${codigo:-000}"
}

chequear_inyeccion() {
  local inyeccion="scripts/dev/qobuz_inyeccion.sh"
  if [[ ! -f "$inyeccion" ]]; then
    echo "::warning::No encuentro scripts/dev/qobuz_inyeccion.sh: el build sale sin pool de Qobuz y sin registro de códigos premium."
    return 0
  fi
  # shellcheck source=/dev/null
  source "$inyeccion"

  # No alcanza con que la URL esté puesta: una ruta sin desplegar o un secreto
  # viejo dan el mismo "hay URL" y ninguna marca de usado. Por eso se pregunta
  # al Worker (12 s como máximo, y sin red solo se avisa).
  if [[ -n "${QOBUZ_POOL_URL:-}" ]]; then
    local codigo_pool
    codigo_pool="$(_http_codigo "$QOBUZ_POOL_URL")"
    case "$codigo_pool" in
      200) echo "  ✓ Pool de Qobuz en el binario y respondiendo (${QOBUZ_POOL_URL%%/pool/*}/pool/…)" ;;
      403) echo "::warning::El /pool del Worker rechaza el secreto (403): revisá QOBUZ_POOL_URL contra QOBUZ_POOL_SECRET del Worker." ;;
      000) echo "::warning::No pude consultar el /pool (sin red o Worker caído): el binario igual sale con la URL inyectada." ;;
      *)   echo "::warning::El /pool del Worker contestó $codigo_pool (se espera 200)." ;;
    esac
  else
    echo "::warning::Sin QOBUZ_POOL_URL: esta compilación sale SIN pool de fábrica (canal firmado directo a Qobuz; si Qobuz lo restringe no hay ARL de rotación)."
  fi

  if [[ -n "${QOBUZ_KEYS_URL:-}" ]]; then
    case "$(_http_codigo "$QOBUZ_KEYS_URL")" in
      200) echo "  ✓ Origen de claves del Worker respondiendo" ;;
      403) echo "::warning::El /keys del Worker rechaza el secreto (403): revisá QOBUZ_KEYS_URL contra QOBUZ_RELAY_SECRET del Worker." ;;
      000) echo "::warning::No pude consultar /keys (sin red o Worker caído)." ;;
      *)   echo "::warning::El /keys del Worker contestó un código inesperado." ;;
    esac
  fi

  if [[ -n "${PREMIUM_REGISTRO_URL:-}" ]]; then
    # Se le pregunta por un código de prueba inválido: lo que importa no es el
    # estado que devuelva, sino que la RUTA exista y el secreto sea el correcto
    # (y que el Worker tenga GITHUB_TOKEN).
    local salida codigo_premium cuerpo_premium
    salida="$(curl -s --max-time 12 -w '\n%{http_code}' -X POST \
      -H 'Content-Type: application/json' -d '{"code":"BITLY2.prueba"}' \
      "$PREMIUM_REGISTRO_URL/verificar" 2>/dev/null)" || true
    codigo_premium="${salida##*$'\n'}"
    cuerpo_premium="${salida%$'\n'*}"

    local problema_premium=""
    case "$codigo_premium" in
      200)
        if [[ "$cuerpo_premium" == *estado* ]]; then
          echo "  ✓ Registro de códigos premium desplegado y respondiendo (los usados se marcan vía el Worker)"
          return 0
        fi
        # 200 sin "estado": el Worker contesta su cadena de salud a cualquier
        # ruta → la versión desplegada es la VIEJA (sin /premium).
        problema_premium="El Worker responde en esa URL, pero SIN la ruta /premium: la versión desplegada es anterior a los códigos. Falta: npx wrangler deploy (desde deeplinks/proxy-qobuz)."
        ;;
      403) problema_premium="El Worker rechaza el secreto (403): PREMIUM_SECRET del Worker y el de la URL no coinciden (o PREMIUM_SECRET no está cargado)." ;;
      404|405) problema_premium="El Worker no tiene la ruta /premium (HTTP $codigo_premium): falta desplegar la versión nueva (npx wrangler deploy)." ;;
      500) problema_premium="El Worker no tiene GITHUB_TOKEN cargado (HTTP 500): npx wrangler secret put GITHUB_TOKEN." ;;
      000) echo "::warning::No pude consultar el registro premium (sin red o Worker caído): el binario sale con la URL, y los códigos se marcan usados cuando el Worker vuelva (quedan pendientes)." ;;
      *)   problema_premium="El registro premium contestó HTTP $codigo_premium (se espera 200 con {\"estado\":…})." ;;
    esac

    if [[ -n "$problema_premium" ]]; then
      if [[ "$SUBIR_RELEASE" == "true" && "${PERMITIR_SIN_REGISTRO:-false}" != "true" ]]; then
        echo "::error::$problema_premium" >&2
        echo "  Si publicás así, los códigos legacy validan pero NO se marcan como usados (un código filtrado sirve para siempre)." >&2
        echo "  Para publicar igual (a sabiendas):  PERMITIR_SIN_REGISTRO=true bash scripts/release/release.sh --upload" >&2
        return 1
      fi
      echo "::warning::$problema_premium"
    fi
    return 0
  fi

  if [[ "$SUBIR_RELEASE" == "true" && "${PERMITIR_SIN_REGISTRO:-false}" != "true" ]]; then
    echo "::error::Esta release saldría SIN registro de códigos premium (falta PREMIUM_REGISTRO_URL en qobuz-worker.env): los códigos legacy validan pero NO se marcan como usados, así que un código que se filtre sirve para siempre." >&2
    echo "  Se arregla una vez (Worker de Cloudflare):" >&2
    echo "    1) npx wrangler secret put GITHUB_TOKEN     # PAT fine-grained, Contents: Read+Write SOLO en QuopTron/bitly_codes_premium" >&2
    echo "    2) npx wrangler secret put PREMIUM_SECRET   # inventá un secreto largo" >&2
    echo "    3) npx wrangler deploy" >&2
    echo "    4) echo 'PREMIUM_REGISTRO_URL=https://<worker>/premium/<PREMIUM_SECRET>' >> qobuz-worker.env" >&2
    echo "  Para publicar igual (a sabiendas):  PERMITIR_SIN_REGISTRO=true bash scripts/release/release.sh --upload" >&2
    return 1
  fi

  echo "::warning::Sin PREMIUM_REGISTRO_URL: este build valida los códigos pero NO los marca como usados."
  return 0
}

chequear_secretos() {
  local problemas=0

  # 1) La fuente: es lo que se compila, así que avisa antes de perder el build.
  if grep -qE "$PAT_CLASICO_RE" lib/config/secretos.dart 2>/dev/null; then
    echo "::error::lib/config/secretos.dart tiene un PAT CLÁSICO de GitHub (ghp_…): da acceso a TODOS tus repos y este valor queda EMBEBIDO en el APK/exe, que se baja de un repo público." >&2
    echo "  Revocalo ya:  https://github.com/settings/tokens" >&2
    echo "  Y usá uno FINE-GRAINED con Contents: Read SOLO sobre QuopTron/bitly_codes_premium (ese es el token premium que sí puede viajar en el binario)." >&2
    problemas=$((problemas + 1))
  fi

  if grep -qE 'github_pat_[A-Za-z0-9_]{20,}' lib/config/secretos.dart 2>/dev/null; then
    echo "::warning::lib/config/secretos.dart usa un token fine-grained (github_pat_…): está bien que sea el premium, pero revisá que sea SOLO Contents: Read sobre bitly_codes_premium y no 'All repositories'." >&2
  fi

  if [ "$problemas" -gt 0 ]; then
    echo "::error::No publico un binario con un token clásico adentro. Arreglá secretos.dart y volvé a correr." >&2
    return 1
  fi
  echo "  ✓ secretos.dart sin PAT clásico embebido"
  return 0
}

# Segunda red, ya con los binarios compilados: revisa lo que se va a subir, así
# también caza un token que no venga de secretos.dart (hardcodeado en Dart, en un
# asset, en una extensión…).
#   · APK: el libapp.so se descomprime con unzip y ahí el grep ve el texto.
#   · .exe de Inno: el payload va comprimido, así que el grep NO ve nada; por eso
#     se revisa el bundle de Flutter (build/windows), que va sin comprimir y es
#     lo que el instalador empaqueta.
chequear_binarios() {
  local problemas=0 f so

  for f in dist/*.apk; do
    if [ ! -f "$f" ]; then continue; fi
    if command -v unzip >/dev/null 2>&1; then
      # Se CUENTA (grep -c) y no se pregunta con `grep -q`: este script corre con
      # `set -o pipefail`, y `grep -q` corta la lectura apenas encuentra el token,
      # así que unzip muere con SIGPIPE (141) y la condición daba FALSA justo
      # cuando el token ESTABA adentro. El conteo lee todo el stream y no rompe.
      local n_so n_token
      n_so=$(unzip -l "$f" 2>/dev/null | grep -c 'libapp\.so' || true)
      if [ "${n_so:-0}" -eq 0 ]; then
        echo "::warning::No encontré libapp.so dentro de $f: no puedo revisarlo por tokens embebidos." >&2
      else
        n_token=$(unzip -p "$f" 'lib/*/libapp.so' 2>/dev/null \
          | grep -acE "$PAT_CLASICO_RE" || true)
        if [ "${n_token:-0}" -gt 0 ]; then
          echo "::error::$f lleva un PAT clásico (ghp_…) embebido: cualquiera lo saca con unzip y este binario va a un repo público." >&2
          problemas=$((problemas + 1))
        fi
      fi
    else
      echo "::warning::No encontré unzip: no puedo revisar $f por tokens embebidos." >&2
    fi
  done

  # `find` en vez de globstar: no depende de opciones de shell.
  while IFS= read -r so; do
    if grep -qaE "$PAT_CLASICO_RE" "$so" 2>/dev/null; then
      echo "::error::El bundle de Windows ($so) lleva un PAT clásico (ghp_…) embebido y el instalador lo empaqueta tal cual." >&2
      problemas=$((problemas + 1))
    fi
  done < <(find build/windows -path '*Release*' -name '*.so' 2>/dev/null | head -20)

  if [ "$problemas" -gt 0 ]; then
    echo "::error::Revocá ese token (https://github.com/settings/tokens), cambiá lib/config/secretos.dart y volvé a compilar." >&2
    return 1
  fi
  echo "  ✓ ningún binario lleva un PAT clásico embebido"
  return 0
}

# ── 0) Chequeo previo del espejo (ANTES de compilar) ─────────────────
# Un build completo tarda muchísimo: enterarse al final de que falta el token
# del espejo, o que a gh le falta permiso para disparar workflows, es perder el
# build entero (los APKs se compilan igual, pero NADIE los puede bajar: la app y
# el sitio leen el repo público). Este chequeo no compila nada y deja cada
# problema con su arreglo.
chequear_espejo() {
  local problemas=0

  if ! command -v gh >/dev/null 2>&1; then
    echo "::error::gh (GitHub CLI) no está instalado: no puedo publicar ni espejar." >&2
    echo "  Instalalo desde https://cli.github.com y corré:  gh auth login" >&2
    return 1
  fi

  if ! gh auth status >/dev/null 2>&1; then
    echo "::error::gh no está autenticado (gh auth status falló)." >&2
    echo "  Corré:  gh auth login" >&2
    return 1
  fi

  # Disparar el espejo es un `gh workflow run`, y eso necesita el scope
  # 'workflow' (tokens clásicos) o Actions: write (fine-grained). Se lee la
  # lista de scopes que reporta gh: si dice 'none' o no dice nada (token
  # fine-grained), no se puede saber de antemano y se sigue igual.
  local scopes
  scopes=$(gh auth status 2>&1 | grep -i 'Token scopes' || true)
  case "$scopes" in
    "") ;;       # gh no reportó la lista (versiones viejas): no se puede saber
    *workflow*) ;; # scope presente (sin comillas: no depende del formato de gh)
    *none*) ;;   # token fine-grained: gh no lista scopes, así que tampoco se sabe
    *)
      echo "::error::Al token de gh le falta el scope 'workflow': el disparo del espejo va a fallar." >&2
      echo "  Arreglalo con:  gh auth refresh -s workflow" >&2
      problemas=$((problemas + 1))
      ;;
  esac

  # El workflow del espejo tiene que existir (y estar activo) en la rama por
  # defecto: si no, el disparo falla o no hace nada.
  local estado
  estado=$(gh api "repos/$REPO_CODIGO/actions/workflows/espejo-releases.yml" --jq '.state' 2>/dev/null || echo "")
  case "$estado" in
    active)
      echo "  ✓ workflow del espejo activo"
      ;;
    "")
      echo "::warning::No pude leer el estado del workflow del espejo (¿el token ve Actions?)." >&2
      echo "  Se sigue, pero si el disparo falla, revisá los permisos del token de gh." >&2
      ;;
    *)
      echo "::error::El workflow del espejo está en estado '$estado' en $REPO_CODIGO." >&2
      problemas=$((problemas + 1))
      ;;
  esac

  # Sin este secret el job del espejo falla (y sin espejo no hay descargas).
  local secretos
  if secretos=$(gh secret list --repo "$REPO_CODIGO" --json name --jq '.[].name' 2>/dev/null); then
    if printf '%s\n' "$secretos" | grep -qx "RELEASES_TOKEN"; then
      echo "  ✓ RELEASES_TOKEN configurado"
    else
      echo "::error::Falta el secret RELEASES_TOKEN en $REPO_CODIGO: el espejo va a fallar y nadie va a poder bajar la release." >&2
      echo "  Crealo una vez (PAT con Contents: Read and write SOLO sobre $ESPEJO_REPO):" >&2
      echo "    gh secret set RELEASES_TOKEN --repo $REPO_CODIGO" >&2
      echo "  Ver docs/06-releases-publicas.md" >&2
      problemas=$((problemas + 1))
    fi
  else
    echo "::warning::No pude listar los secretos de $REPO_CODIGO (¿permiso del token de gh?)." >&2
    echo "  No se si RELEASES_TOKEN está: si el espejo falla, empezá por ahi." >&2
  fi

  # La app consulta la API SIN token: si el repo público no existe (o es
  # privado), todo esto no sirve de nada.
  if command -v curl >/dev/null 2>&1; then
    local codigo
    codigo=$(curl -s -o /dev/null -m 15 -w '%{http_code}' \
      "https://api.github.com/repos/$ESPEJO_REPO" 2>/dev/null || echo "000")
    case "$codigo" in
      200)
        echo "  ✓ $ESPEJO_REPO responde sin token (como lo ve la app)"
        ;;
      404)
        echo "::error::La API pública responde 404 para $ESPEJO_REPO: no existe o es privado, así que la app y el sitio no van a poder bajar nada." >&2
        problemas=$((problemas + 1))
        ;;
      *)
        echo "::warning::La API pública respondió HTTP $codigo para $ESPEJO_REPO (¿rate limit o red?)." >&2
        ;;
    esac
  else
    echo "  · no encontré curl: me salteo la comprobación anónima de $ESPEJO_REPO"
  fi

  # Si la variable del workflow apunta a OTRO repo, el espejo escribiría en uno
  # y la app (y esta verificación) leería en otro.
  local var_pub
  var_pub=$(gh variable list --repo "$REPO_CODIGO" --json name,value \
    --jq '.[] | select(.name=="PUBLIC_RELEASES_REPO") | .value' 2>/dev/null || true)
  if [[ -n "$var_pub" && "$var_pub" != "$ESPEJO_REPO" ]]; then
    echo "::error::PUBLIC_RELEASES_REPO=$var_pub no es el repo que lee la app ($ESPEJO_REPO): el espejo escribiría en un lado y la app leería en otro." >&2
    problemas=$((problemas + 1))
  fi

  if [ "$problemas" -gt 0 ]; then
    echo "" >&2
    echo "::error::El espejo público no va a quedar bien ($problemas problema(s)): arreglá lo de arriba y volvé a correr (así no perdés el build)." >&2
    return 1
  fi
  echo "✅ Espejo listo para funcionar."
  return 0
}

if [[ "$SUBIR_RELEASE" == "true" ]]; then
  echo "==> Chequeo previo del espejo público (antes de compilar)..."
  chequear_espejo
  chequear_secretos
else
  echo "==> Sin --upload: esta corrida no espeja, así que no chequeo el espejo."
fi

echo ""

CURRENT=$(grep -E '^version:' pubspec.yaml | sed 's/version: *//' | tr -d ' \r')
# Se chequea ANTES de tocar la versión y de compilar: si falta algo que hace
# que la release no marque códigos como usados, mejor saberlo sin gastar build.
chequear_inyeccion

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

if [[ -n "$VERSION_ARG" ]]; then
  NEW_VERSION="$VERSION_ARG"
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

# ── 2a) Backend Go → AAR de Android ─────────────────────────────────
# El backend Go NO es código Dart: viaja DENTRO del APK como el artefacto
# libs/bitly.aar, que gradle lee con implementation(files("libs/bitly.aar")).
# Si no se recompila acá, el APK publica el backend VIEJO aunque el código de
# go_backend/ haya cambiado (síntoma clásico: "arreglé algo en Go y la app
# sigue igual"). go_backend/build.sh aar hace el bind y copia el resultado a
# android/app/libs/bitly.aar, así que es la única fuente de verdad del AAR.
#
# OJO: el workflow de CI (.github/workflows/release.yml) esto YA lo hace; sin
# este paso el release local y el de CI podían publicar binarios distintos.
if [[ "$REHACER_AAR" == "true" ]]; then
  if ! command -v gomobile >/dev/null 2>&1; then
    echo "::error::gomobile no está en el PATH, así que no puedo recompilar el AAR del backend." >&2
    echo "  Instalalo:  go install golang.org/x/mobile/cmd/gomobile@latest" >&2
    echo "  O reusá el AAR ya compilado con:  bash scripts/release/release.sh --no-aar" >&2
    exit 1
  fi
  echo "==> Recompilando el backend Go (AAR de Android)..."
  ( cd go_backend && bash ./build.sh aar )
else
  echo "==> --no-aar: reusando android/app/libs/bitly.aar tal como está."
  if [[ ! -f android/app/libs/bitly.aar ]]; then
    echo "::error::No existe android/app/libs/bitly.aar y se pidió --no-aar" >&2
    exit 1
  fi
fi

# El APK x86_64 (emulador / Chromebook) NO entra por defecto: build.gradle.kts
# lo excluye salvo INCLUDE_X86_64=true. Como acá SIEMPRE se publican los 3
# APKs, se activa explícitamente.
export INCLUDE_X86_64="${INCLUDE_X86_64:-true}"

echo "==> Compilando APKs (split-per-abi, INCLUDE_X86_64=$INCLUDE_X86_64)..."
flutter build apk --release --split-per-abi \
  --split-debug-info=build/symbols
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
  bash scripts/build/build_windows_release.sh
fi

echo "==> Artefactos en dist/:"
ls -lh dist/

# ── 3) Commit + tag + push ──────────────────────────────────────────
# Solo el bump va al repo; los binarios se suben a la GitHub Release
# (nunca se commitean APKs/instaladores al git).
git add -A
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
- **La versión web ya reproduce música (player nuevo en el navegador)**: la lógica de reproducción —cola, crossfade, precarga, anti-cortes, velocidad y volumen— ahora habla contra una interfaz de audio, y cada plataforma la implementa: media_kit/mpv en Android/Mac/PC/TV y el reproductor HTML del navegador en la web.
- **El motor se elige al compilar, no en tiempo de ejecución**: cuando se compila para Android/PC, el código de la web ni se mira (y al revés). Nada cambia en las plataformas que ya usabas: mismo motor, misma configuración, mismo sonido.
- **La web ahora explica qué necesita en vez de mostrar un error técnico**: si abrís la versión web sin el servidor de Bitly encendido, aparece una pantalla que cuenta por qué la web lo necesita (los navegadores no pueden pedir la música por su cuenta) y te manda a la app de Android/Windows/macOS/iOS, que no necesita nada extra. Antes decía "Backend no responde" con un botón que nunca iba a funcionar.
- **Un bug clásico de volumen, cerrado en un solo lugar**: mpv mide el volumen de 0 a 100 y el navegador de 0 a 1. La conversión ahora vive en el motor de cada plataforma, así no puede volver el fallo de "reproduce a 1% e inaudible".

### ✅ Verificado en un navegador real
El player web se probó de punta a punta en Chrome contra un audio remoto: duración detectada (6:12), la posición avanza, salto dentro del tema (60 s), volumen, velocidad 1.5x, pausa/reanudar, detener y liberación del motor. Todo en verde. La app además compila para web y arranca sin excepciones.

### ⚠️ Sobre la versión web
La web funciona con el servidor de Bitly (`bitly-backend --web`) encendido en tu computadora o en un servidor propio: no es una app que se instala sola y no se descarga desde acá. Se abre desde el navegador de esa misma máquina, o desde otro dispositivo de la misma red.

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
- **The web version now plays music (new browser player)**: the playback logic —queue, crossfade, preloading, stall watchdogs, speed and volume— now talks to an audio interface, and each platform implements it: media_kit/mpv on Android/Mac/PC/TV and the browser's HTML player on the web.
- **The engine is chosen at build time, not at runtime**: when you build for Android/PC, the web code is not even looked at (and vice versa). Nothing changes on the platforms you already use: same engine, same configuration, same sound.
- **The web now explains what it needs instead of showing a technical error**: if you open the web version without the Bitly server running, you get a screen that explains why the web needs it (browsers cannot fetch the music on their own) and points you to the Android/Windows/macOS/iOS app, which needs nothing extra. It used to say "Backend not responding" with a button that was never going to work.
- **A classic volume bug, closed in one place**: mpv measures volume 0-100 and the browser 0-1. The conversion now lives in each platform's engine, so the "plays at 1% and inaudible" failure cannot come back.

### ✅ Verified in a real browser
The web player was tested end to end in Chrome against a remote audio file: duration detected (6:12), position advancing, seek within the track (60 s), volume, 1.5x speed, pause/resume, stop and engine disposal. All green. The app also builds for web and boots with no exceptions.

### ⚠️ About the web version
The web version runs with the Bitly server (`bitly-backend --web`) turned on, on your computer or on a server of your own: it is not an app that installs itself, and it is not downloaded from here. You open it from a browser on that same machine, or from another device on the same network.

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

  # Antes de publicar: ningún binario puede salir con un token clásico adentro.
  echo "==> Chequeando que los binarios no lleven tokens embebidos..."
  chequear_binarios

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

  # ── 5) Espejo PÚBLICO al repo de descargas (OBLIGATORIO) ──────────
  # La app y el sitio NO leen este repo (es privado: sus assets exigen token),
  # sino el repo público de releases (QuopTron/bitly-releases). El espejo
  # (espejo-releases.yml) copia los assets con el mismo tag.
  #
  # Es OBLIGATORIO y VERIFICADO: se dispara y se espera a que los binarios
  # aparezcan en el repo público, uno por uno. Si el espejo no corre (o al token
  # de gh le falta el permiso 'workflow'), o si algún binario no llega, el script
  # FALLA: una release que la app no puede ver es una release a medias.
  echo ""
  echo "==> Espejando los binarios al repo público ($ESPEJO_REPO)..."

  # Dispararlo es obligatorio: si esto no sale, la release existe pero NADIE
  # puede bajarla desde la app ni desde el sitio (leen el repo público, no este
  # privado). Por eso ahora falla en vez de avisar y seguir.
  if ! gh workflow run espejo-releases.yml --repo "$REPO_CODIGO" -f tag="v${NEW_VERSION}"; then
    echo "::error::No pude disparar el espejo público: la app y el sitio NO ven esta release." >&2
    echo "  (¿le falta el permiso 'workflow' al token de gh? Se arregla con:  gh auth refresh -s workflow)" >&2
    echo "  Disparálo a mano:  gh workflow run espejo-releases.yml --repo QuopTron/bitly -f tag=v${NEW_VERSION}" >&2
    exit 1
  fi
  echo "✅ Espejo disparado. Esperando a que los binarios aparezcan en el repo público..."

  # Nombres que publicó ESTE script (los que tienen que quedar espejados).
  # Los de Apple (.dmg/.ipa) los agrega su propio workflow después.
  ESPERADOS=()
  for f in dist/app-*-release.apk dist/Bitly-Setup-*.exe; do
    # Con if explícito y no con `&&`: si el patrón no matchea (--windows no se
    # usó), la última sentencia del for devolvía 1 y `set -e` cortaba el script.
    if [ -f "$f" ]; then ESPERADOS+=("$(basename "$f")"); fi
  done

  ESPERA="${ESPERA_ESPEJO:-300}" # segundos (5 min por defecto)
  TRANSCURRIDO=0
  FALTAN=""
  while :; do
    # join(" "): los nombres tienen que venir SEPARADOS POR ESPACIOS (con saltos
    # de línea, el `case` de abajo nunca matcheaba y todo se reportaba faltante).
    PRESENTES=$(gh release view "v${NEW_VERSION}" --repo "$ESPEJO_REPO" \
      --json assets --jq '[.assets[].name] | join(" ")' 2>/dev/null || true)
    FALTAN=""
    for nombre in ${ESPERADOS[@]+"${ESPERADOS[@]}"}; do
      case " $PRESENTES " in *" $nombre "*) ;; *) FALTAN="$FALTAN $nombre" ;; esac
    done
    if [ -z "$FALTAN" ]; then break; fi
    if [ "$TRANSCURRIDO" -ge "$ESPERA" ]; then break; fi
    sleep 15
    TRANSCURRIDO=$((TRANSCURRIDO + 15))
  done

  if [ -n "$FALTAN" ]; then
    echo "::error::El espejo público todavía no tiene:$FALTAN (esperé ${TRANSCURRIDO}s)." >&2
    echo "  Mirá el run:  gh run list --repo QuopTron/bitly --workflow=espejo-releases.yml" >&2
    echo "  O subilos a mano:  gh release upload v${NEW_VERSION} dist/<archivo> --repo $ESPEJO_REPO" >&2
    exit 1
  fi
  echo "✅ v${NEW_VERSION} ya está en $ESPEJO_REPO con los binarios de Android/PC."

  # Aviso (no error): los binarios de Apple los publica su propio workflow, así
  # que todavía pueden no estar. Se busca el sufijo en cualquier posición (los
  # assets no vienen en un orden fijo).
  case " $PRESENTES " in
    *".dmg"* | *".ipa"*) ;;
    *)
      echo "::warning::La release pública todavía no tiene macOS(.dmg) / iOS(.ipa)."
      echo "   Compilalos y espejalos con:"
      echo "     gh workflow run release-macos.yml --repo QuopTron/bitly -f upload_release=true -f tag=v${NEW_VERSION}"
      ;;
  esac
else
  echo ""
  echo "✅ Listo. Para SUBIR el release (con --upload), los binarios ya están en dist/."
  echo "   Subida manual: GitHub → Releases → Edit release → Drag & drop en 'Attach binaries'."
  echo "   Apple (macOS + iOS), desde este mismo repo:"
  echo "     gh workflow run release-macos.yml --repo QuopTron/bitly -f upload_release=true -f tag=v${NEW_VERSION}"
fi