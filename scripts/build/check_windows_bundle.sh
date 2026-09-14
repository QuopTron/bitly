#!/usr/bin/env bash
#
# check_windows_bundle.sh — Verifica que el bundle de Windows traiga el runtime
# de Visual C++ (MSVC).
#
# Qué bug cubre:
#   bitly.exe, flutter_windows.dll y los DLLs de plugins se compilan con MSVC y
#   enlazan dinámicamente contra el CRT (msvcp140.dll, vcruntime140.dll,
#   vcruntime140_1.dll). Si esas DLLs NO viajan en la carpeta Release, la app
#   solo arranca en una PC que ya tenga instalado el "Redistribuible de Visual
#   C++ 2015-2022"; en una PC nueva Windows muestra "no se encuentra
#   VCRUNTIME140.dll" y el proceso se cierra sin más. Reportado como "el exe no
#   es compatible con las arquitecturas nuevas" (no es la CPU: es el runtime).
#
#   El empaquetado lo hace windows/CMakeLists.txt con
#   InstallRequiredSystemLibraries, que además elige el CRT de la arquitectura
#   que se está compilando. Este script es la COMPROBACIÓN, para que un bundle
#   sin CRT no llegue nunca a un instalador que recién falla en la PC del
#   usuario. Lo llaman tanto build_windows_release.sh como los workflows.
#
# Uso:
#   bash scripts/build/check_windows_bundle.sh build/windows/x64/runner/Release
#
# Parte del flujo: release de escritorio (Windows).

set -euo pipefail

DIR="${1:-}"
if [[ -z "$DIR" ]]; then
  echo "::error::Uso: check_windows_bundle.sh <carpeta Release>" >&2
  exit 2
fi
if [[ ! -d "$DIR" ]]; then
  echo "::error::No existe la carpeta del bundle: $DIR" >&2
  exit 2
fi

# Los tres que exige cualquier binario MSVC moderno. vcruntime140_1.dll solo
# hace falta en x64/arm64 (manejo de excepciones estructuradas) y es justo el
# que más se olvida al empaquetar a mano: por eso se pide explícitamente.
FALTAN=()
for dll in msvcp140.dll vcruntime140.dll vcruntime140_1.dll; do
  [[ -f "$DIR/$dll" ]] || FALTAN+=("$dll")
done

if (( ${#FALTAN[@]} > 0 )); then
  echo "::error::El bundle no trae el runtime de C++: ${FALTAN[*]}" >&2
  echo "          La app NO arrancaría en una PC sin el Redistribuible de Visual C++." >&2
  echo "          Revisá que windows/CMakeLists.txt incluya InstallRequiredSystemLibraries" >&2
  echo "          y borrá build/windows para forzar un configure limpio." >&2
  exit 1
fi

echo "✔ CRT presente en $DIR: msvcp140.dll · vcruntime140.dll · vcruntime140_1.dll"
