# preparar_libtorrent_windows.ps1 — deja los binarios prebuilt de
# libtorrent_flutter en el cache de pub ANTES de compilar la app.
#
# Por qué existe: el CMakeLists del plugin extrae su zip con
# `cmake -E tar xf`, que usa libarchive. En el runner de CI el plugin vive
# detrás de windows/flutter/ephemeral/.plugin_symlinks (un symlink), y
# libarchive RECHAZA escribir a través de un symlink:
#   "Problem with archive_write_header(): Cannot extract through symlink"
# En una PC local nunca se ve porque el DLL ya quedó extraído en el cache y
# el plugin salta todo el bloque de descarga. Acá hacemos lo mismo de forma
# explícita: bajamos el zip y lo expandimos con Expand-Archive (que no tiene
# esa restricción), dejando el DLL donde el plugin lo busca.
#
# Es idempotente: si el DLL ya está, no hace nada.

param(
  [ValidateSet("", "x64", "arm64")]
  [string]$Arch = ""
)

$ErrorActionPreference = "Stop"

if (-not $Arch) {
  if ($env:PROCESSOR_ARCHITECTURE -match "ARM64") { $Arch = "arm64" } else { $Arch = "x64" }
}
Write-Host "libtorrent_flutter: preparando prebuilt para $Arch"

$cache = Join-Path $env:LOCALAPPDATA "Pub\Cache\hosted\pub.dev"
if (-not (Test-Path $cache)) {
  Write-Host "No existe el cache de pub ($cache); nada que preparar."
  exit 0
}

$plugin = Get-ChildItem $cache -Directory -Filter "libtorrent_flutter-*" -ErrorAction SilentlyContinue |
  Sort-Object Name -Descending | Select-Object -First 1
if (-not $plugin) {
  Write-Host "libtorrent_flutter no está en el cache de pub; nada que preparar."
  exit 0
}

$dest = Join-Path $plugin.FullName "prebuilt\windows\$Arch"
$dll = Join-Path $dest "libtorrent_flutter.dll"
if (Test-Path $dll) {
  Write-Host "Prebuilt ya presente: $dll"
  exit 0
}

$versionLine = Select-String -Path (Join-Path $plugin.FullName "pubspec.yaml") -Pattern '^version:\s*([^\s]+)'
$version = $versionLine.Matches[0].Groups[1].Value
$url = "https://github.com/ayman708-UX/libtorrent_flutter/releases/download/v$version/windows-native-lib-$Arch.zip"

Write-Host "Descargando $url"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$zip = Join-Path $env:TEMP "libtorrent_flutter-$Arch.zip"
$tmp = Join-Path $env:TEMP "libtorrent_flutter-$Arch-expand"
try {
  Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
  # Se expande fuera del symlink y después se copia: así libarchive no ve
  # ningún enlace en el camino de escritura.
  Expand-Archive -Path $zip -DestinationPath $tmp -Force
  Copy-Item -Path (Join-Path $tmp "*") -Destination $dest -Recurse -Force
} finally {
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
  if (Test-Path $zip) { Remove-Item -Force $zip }
}

if (-not (Test-Path $dll)) {
  throw "No quedó libtorrent_flutter.dll en $dest (revisá el contenido del zip)"
}
$count = (Get-ChildItem $dest -Filter *.dll).Count
Write-Host "Prebuilt listo: $dll ($count DLLs en $dest)"
