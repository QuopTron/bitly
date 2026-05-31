# 🔴 PROBLEMA CRÍTICO: gomobile NO exporta funciones al AAR

## Diagnóstico Completo

### Síntoma
```
MissingPluginException(No implementation found for method setStoreRegistryUrl on channel com.zarz.spotiflac/backend)
MissingPluginException(No implementation found for method downloadStoreExtension on channel com.zarz.spotiflac/backend)
MissingPluginException(No implementation found for method InitMasterDatabaseJSON on channel com.zarz.spotiflac/backend)
```

### Investigación Realizada

1. ✅ Funciones existen en exports.go y son públicas
2. ✅ Firmas de funciones son válidas para gomobile (string, int, error)
3. ✅ AAR se genera correctamente (74MB)
4. ❌ **Funciones NO están en el AAR** (verificado extrayendo classes.jar)
5. ❌ **Package NO compila para Android** - errores de dependencias

### Causa Raíz

**`modernc.org/sqlite` NO funciona con gomobile para Android**

```
C:\Users\Carlos_M\go\pkg\mod\modernc.org\libc@v1.72.3\libc.go:33:2: cannot find package
C:\Users\Carlos_M\go\pkg\mod\modernc.org\libc@v1.72.3\pthread.go:17:2: cannot find package
C:\Users\Carlos_M\go\pkg\mod\modernc.org\libc@v1.72.3\etc.go:25:2: cannot find package
```

`modernc.org/sqlite` → `modernc.org/libc` → Requiere C standard library que NO está disponible en Android NDK.

**gomobile bind silenciosamente falla y NO exporta NINGUNA función del package cuando hay errores de compilación.**

### Código Problemático

```go
// database.go
import (
    _ "modernc.org/sqlite"  // ← ESTO causa el error de compilación
)

func InitMasterDatabase(path string) error {
    db, err := sql.Open("sqlite", path)  // ← Usa modernc.org/sqlite
    // ...
}

// exports.go
func InitMasterDatabaseJSON(path string) error {
    return InitMasterDatabase(path)  // ← NO se exporta por el error de compilación
}

func SetStoreRegistryURLJSON(registryURL string) error {
    // ...  // ← TAMPOCO se exporta, aunque NO usa SQLite
}
```

## Soluciones

### Opción 1: Build Tags para Excluir Funciones DB (Rápida) ✅ RECOMENDADA

**Idea:** Separar funciones que usan SQLite con build tags

```go
// database.go
//go:build !android

package gobackend

// Funciones que usan SQLite - NO se compilan para Android
```

```go
// database_android.go  
//go:build android

package gobackend

// Stub functions para Android - no hacen nada o usan alternativa
func InitMasterDatabase(path string) error {
    return fmt.Errorf("database not available on Android")
}
```

**Ventajas:**
- ✅ Rápido de implementar
- ✅ Funciones que NO usan SQLite SÍ se exportarán
- ✅ No requiere cambios en arquitectura

**Desventajas:**
- ❌ Database no funciona en Android
- ❌ Extensiones y registry URL funcionarán, pero no library

---

### Opción 2: SQLite Nativo de Android (Mejor a Largo Plazo)

**Idea:** Inicializar DB desde Kotlin/Java, pasar a Go

```kotlin
// MainActivity.kt
val db = SQLiteDatabase.openOrCreateDatabase("path/to/db", null)
Gobackend.initMasterDatabaseWithHandle(db.nativeHandle)
```

```go
// database_android.go
//go:build android

import "C"

//export InitMasterDatabaseWithHandle
func InitMasterDatabaseWithHandle(handle int64) error {
    // Usar handle de SQLite nativo
    // Requiere mattn/go-sqlite3 con CGO
}
```

**Ventajas:**
- ✅ Database funciona en Android
- ✅ Usa SQLite nativo (mejor performance)

**Desventajas:**
- ❌ Requiere CGO y NDK
- ❌ Complejo de implementar
- ❌ Cambios significativos en arquitectura

---

### Opción 3: mattn/go-sqlite3 con CGO

**Idea:** Reemplazar modernc.org/sqlite con mattn/go-sqlite3

```go
import (
    _ "github.com/mattn/go-sqlite3"  // Usa CGO, funciona con NDK
)
```

**Ventajas:**
- ✅ Database funciona en Android
- ✅ Compatible con gomobile

**Desventajas:**
- ❌ Requiere CGO_ENABLED=1
- ❌ Requiere NDK configurado
- ❌ Build más complejo y lento

---

## Plan de Acción Recomendado

### Paso 1: Implementar Opción 1 (Build Tags) - 30 minutos
1. Agregar `//go:build !android` a database.go
2. Crear database_android.go con stubs
3. Rebuild AAR
4. Verificar que SetStoreRegistryURLJSON SÍ se exporta

### Paso 2: Testear Extensiones
1. Verificar que extension store carga
2. Verificar que registry URL se configura
3. Extensiones deberían funcionar (no usan DB)

### Paso 3: Implementar Opción 2 (Database Nativo) - Futuro
1. Investigar pasar SQLite handle de Android a Go
2. Implementar init desde Kotlin
3. Reemplazar stubs con implementación real

---

## Referencias

- gomobile bind docs: https://pkg.go.dev/golang.org/x/mobile/cmd/gomobile
- Supported types: https://pliutau.com/gomobile-bind-types/
- GitHub issue: https://github.com/golang/go/issues/37961

---

**Fecha:** 2026-05-25 23:59
**Estado:** 🔴 Bloqueado - Requiere decisión del usuario
**Impacto:** Extensiones y registry URL NO funcionan en Android
