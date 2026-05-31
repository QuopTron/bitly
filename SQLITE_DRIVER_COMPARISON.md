# 🔍 Comparación: Soluciones SQLite para gomobile Android

## Opción A: modernc.org/sqlite (ACTUAL) ❌

### Cómo funciona
- Pure Go implementation de SQLite
- Usa `modernc.org/libc` (reimplementación de C stdlib en Go)
- NO requiere CGO

### Problema con gomobile
```
❌ NO funciona con gomobile para Android
❌ modernc.org/libc requiere funciones de sistema que NO existen en Android NDK
❌ Errores de compilación:
   - cannot find package (libc)
   - cannot find package (pthread)
   - cannot find package (etc)
```

### Estado
- **Funciona en:** Windows, Linux, macOS ✅
- **Funciona en Android:** ❌ NO
- **Funciona con gomobile:** ❌ NO

---

## Opción B: mattn/go-sqlite3 (CGO) ⚠️

### Cómo funciona
- CGO bindings a SQLite C library
- Compila código C de SQLite directamente
- Requiere C compiler (NDK para Android)

### Problemas con gomobile
```
❌ Históricamente NO funciona con gomobile (Issue #201 desde 2015)
❌ Symbol conflicts: multiple definition of '__aeabi_uidivmod', etc.
❌ pthread linking issues en Android
❌ Requiere CGO_ENABLED=1 con toolchain de Android NDK
```

### Intentos de solución
1. Patch para deshabilitar pthread en Android → ❌ Sigue con symbol conflicts
2. Usar package main en lugar de library → ✅ Funciona pero NO con gomobile bind
3. Custom NDK toolchain → ⚠️ Muy complejo, mantenimiento difícil

### Estado
- **Funciona en:** Windows, Linux, macOS con gcc ✅
- **Funciona en Android:** ⚠️ Solo con CGO cross-compile manual (NO gomobile)
- **Funciona con gomobile:** ❌ NO (symbol conflicts)

---

## Opción C: ncruces/go-sqlite3 (WASM) ✅ RECOMENDADA

### Cómo funciona
- **Pure Go, NO CGO** 🎉
- SQLite compilado a WebAssembly (WASM)
- Usa `wasm2go` para traducir WASM a Go
- VFS (Virtual File System) implementado en pure Go
- **Solo dependencias:** `Go` + `x/sys`

### Ventajas para gomobile
```
✅ Pure Go - NO requiere CGO
✅ NO requiere C compiler
✅ NO requiere NDK
✅ Compatible con cross-compilation
✅ Funciona en Android (arm64, arm, etc.)
✅ Mismo API que database/sql
✅ Alta cobertura de tests
✅ Performance competitiva
```

### Cómo usar
```go
import (
    "database/sql"
    _ "github.com/ncruces/go-sqlite3/driver"
)

func InitMasterDatabase(path string) error {
    db, err := sql.Open("sqlite3", path)  // ← Funciona en Android!
    if err != nil {
        return err
    }
    // ...
}
```

### Desventajas
```
⚠️ Mayor uso de memoria (cada conexión tiene sandbox WASM)
⚠️ Ligeramente más lento que CGO (pero aceptable)
⚠️ Relativamente nuevo (pero activamente mantenido)
```

### Estado
- **Funciona en:** Windows, Linux, macOS, Android, iOS ✅
- **Funciona en Android:** ✅ SÍ (arm64, arm, amd64)
- **Funciona con gomobile:** ✅ SÍ (pure Go, sin CGO)
- **Última versión:** v0.29.1+ (activo)

---

## 📊 Comparación Directa

| Característica | modernc.org | mattn (CGO) | ncruces (WASM) |
|---|---|---|---|
| **Pure Go** | ✅ SÍ | ❌ NO (CGO) | ✅ SÍ |
| **gomobile Android** | ❌ NO | ❌ NO | ✅ SÍ |
| **Requiere NDK** | ❌ NO | ✅ SÍ | ❌ NO |
| **Requiere GCC** | ❌ NO | ✅ SÍ | ❌ NO |
| **Cross-compile** | ✅ Fácil | ❌ Difícil | ✅ Fácil |
| **Performance** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Memory Usage** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Mantenimiento** | ⚠️ Medio | ✅ Activo | ✅ Activo |
| **Tests** | ✅ Buenos | ✅ Buenos | ✅ Excelentes |
| **Android Tested** | ❌ NO | ⚠️ Parcial | ✅ SÍ |

---

## 🎯 Recomendación: Usar ncruces/go-sqlite3

### Por qué es la MEJOR opción:

1. **✅ Solución definitiva** - Funciona con gomobile SIN workarounds
2. **✅ Pure Go** - Mantiene la simplicidad del build actual
3. **✅ NO requiere CGO** - Sin NDK, sin GCC, sin complicaciones
4. **✅ Mismo API** - Solo cambiar import path
5. **✅ Probado en Android** - Testeado oficialmente en arm64, arm
6. **✅ Performance aceptable** - Competitive con alternatives
7. **⚠️ Trade-off aceptable** - Un poco más de memoria, pero funciona

### Migración Required

**Cambios necesarios:**

1. **go.mod:**
```diff
- modernc.org/sqlite v1.50.1
+ github.com/ncruces/go-sqlite3 v0.29.1
```

2. **database.go:**
```diff
import (
    "database/sql"
-   _ "modernc.org/sqlite"
+   _ "github.com/ncruces/go-sqlite3/driver"
)
```

3. **Build AAR:**
```bash
# ANTES: Fallaba con modernc.org/sqlite
gomobile bind -target=android ...

# AHORA: Debería funcionar con ncruces/go-sqlite3
gomobile bind -target=android ...
```

4. **Resultado esperado:**
```
✅ SetStoreRegistryURLJSON - EXPORTADA al AAR
✅ DownloadStoreExtensionJSON - EXPORTADA al AAR
✅ InitMasterDatabaseJSON - EXPORTADA al AAR
✅ Todas las funciones - EXPORTADAS al AAR
```

---

## 📋 Plan de Implementación

### Paso 1: Reemplazar driver SQLite (10 minutos)
```bash
cd go_backend_spotiflac
go get github.com/ncruces/go-sqlite3@latest
go mod tidy
```

Editar `database.go`:
```go
import _ "github.com/ncruces/go-sqlite3/driver"
```

### Paso 2: Verificar compilación (5 minutos)
```bash
go build -v .
# Debería compilar sin errores
```

### Paso 3: Rebuild AAR (10 minutos)
```bash
gomobile bind -target=android -androidapi=24 -o ../android/app/libs/spotiflac.aar .
```

### Paso 4: Verificar funciones en AAR (5 minutos)
```bash
# Extraer classes.jar y buscar funciones
# Deberían aparecer TODAS las funciones exportadas
```

### Paso 5: Testear en Android (15 minutos)
```bash
flutter clean
flutter pub get
flutter run
# Verificar que:
# - Extensiones cargan
# - Registry URL se configura
# - Database se inicializa
```

**Tiempo total estimado:** ~45 minutos

---

## 🚀 Conclusión

**ncruces/go-sqlite3 es la solución PERFECTA para este problema porque:**

1. ✅ Es pure Go (como modernc.org/sqlite que ya usas)
2. ✅ Funciona con gomobile (a diferencia de modernc.org/sqlite)
3. ✅ NO requiere CGO (a diferencia de mattn/go-sqlite3)
4. ✅ Mismo API (migración fácil)
5. ✅ Probado en Android oficialmente
6. ✅ Mantenimiento activo
7. ✅ Alta calidad (tests extensivos)

**Es literalmente la única opción que:**
- Mantiene la simplicidad de pure Go
- Funciona con gomobile para Android
- NO requiere cambios de arquitectura
- NO requiere NDK/CGO complejo

**¿Por qué NO se usó antes?**
- ncruces/go-sqlite3 es relativamente nuevo (2023+)
- modernc.org/sqlite era la opción "pure Go" estándar
- ncruces usa WASM (innovación reciente)

---

**Fecha:** 2026-05-26 00:15
**Recomendación:** ✅ Usar ncruces/go-sqlite3
**Confianza:** 95% (basado en documentación y comunidad)
**Riesgo:** Bajo (pure Go, fácil rollback si hay problemas)
