# Script para renombrar archivos y carpetas de snake_case a camelCase

function Convert-ToCamelCase {
    param([string]$name)
    
    # Remover extensión si existe
    $extension = ""
    if ($name.Contains('.')) {
        $lastDot = $name.LastIndexOf('.')
        $extension = $name.Substring($lastDot)
        $name = $name.Substring(0, $lastDot)
    }
    
    # Dividir por guiones bajos y convertir a camelCase
    $parts = $name.Split('_')
    $result = $parts[0]
    
    for ($i = 1; $i -lt $parts.Length; $i++) {
        $part = $parts[$i]
        if ($part.Length -gt 0) {
            $result += $part.Substring(0, 1).ToUpper() + $part.Substring(1)
        }
    }
    
    return $result + $extension
}

function Rename-DirectoryContents {
    param([string]$path)
    
    # Primero renombrar archivos y carpetas en el nivel actual
    Get-ChildItem -Path $path | ForEach-Object {
        $newName = Convert-ToCamelCase $_.Name
        if ($newName -ne $_.Name) {
            $newPath = Join-Path $path $newName
            Write-Host "Renombrando: $($_.FullName) -> $newPath"
            Rename-Item -Path $_.FullName -NewName $newName
            # Actualizar la ruta para procesar subdirectorios
            $_.FullName = $newPath
        }
    }
    
    # Luego procesar subdirectorios (después de renombrarlos)
    Get-ChildItem -Path $path -Directory | ForEach-Object {
        Rename-DirectoryContents $_.FullName
    }
}

# Función recursiva para renombrar desde abajo hacia arriba
function Rename-FromBottomUp {
    param([string]$path)
    
    # Primero procesar subdirectorios
    Get-ChildItem -Path $path -Directory | ForEach-Object {
        Rename-FromBottomUp $_.FullName
    }
    
    # Luego renombrar archivos y carpetas en este nivel
    Get-ChildItem -Path $path | ForEach-Object {
        $newName = Convert-ToCamelCase $_.Name
        if ($newName -ne $_.Name) {
            $newPath = Join-Path $path $newName
            Write-Host "Renombrando: $($_.FullName) -> $newPath"
            Rename-Item -Path $_.FullName -NewName $newName
        }
    }
}

# Ejecutar en el directorio lib
$libPath = "E:\Pablo\proyectos\bitly\lib"
Write-Host "Iniciando renombrado en: $libPath"
Rename-FromBottomUp -path $libPath
Write-Host "Renombrado completado!"
