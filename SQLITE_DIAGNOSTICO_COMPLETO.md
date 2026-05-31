# 🔍 Diagnóstico Completo del Sistema SQLite

**Fecha:** 2026-05-27  
**Problema:** Múltiples errores de tablas faltantes y métodos no implementados  
**Archivos Analizados:** `database.go`, `exports.go`, `cmd/server/main.go`

---

## 🚨 Problemas Identificados

### 1. **PROBLEMA CRÍTICO: Falta de Inicialización del Esquema de BD**

**Causa Raíz:**  
El método `InitMasterDatabase()` en `database.go:19-41` **NO crea las tablas necesarias**. Solo abre la conexión SQLite y configura pragmas de optimización:

```go
func InitMasterDatabase(path string) error {
    // Solo abre la conexión
    db, err := sql.Open("sqlite3", path)
    // Configura pragmas (WAL, cache, etc.)
    _, _ = db.Exec("PRAGMA journal_mode=WAL")
    // NO HAY CREACIÓN DE TABLAS
    return nil
}
```

**Impacto:**  
Cuando la aplicación intenta usar tablas, recibe el error:
```
sqlite3: SQL logic error: no such table: application_state
```

---

### 2. **Tabla Faltante: `application_state`**

**Usada en:**
- `SaveAppSettings()` - línea 1966
- `LoadAppSettings()` - línea 1973

**Estructura Requerida:**
```sql
CREATE TABLE IF NOT EXISTS application_state (
    key TEXT PRIMARY KEY NOT NULL,
    value TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
```

**Operaciones que fallan:**
- Guardar configuración de la app
- Cargar configuración de la app

---

### 3. **Métodos Implementados Pero No Funcionan (MissingPluginException)**

Los siguientes métodos **están implementados** en `database.go` pero reportan `MissingPluginException`:

#### a) `getDownloadEntryBySpotifyID`
- **Implementado en:** `database.go:554-564`
- **Exportado en:** `cmd/server/main.go:995-1001` 
- **Status:** ✅ Implementado correctamente
- **Problema:** Requiere tabla `metadata` y `files`

#### b) `findDownloadEntryByTrackAndArtist`
- **Implementado en:** `database.go:578-589`
- **Exportado en:** `cmd/server/main.go:1005-1011`
- **Status:** ✅ Implementado correctamente
- **Problema:** Requiere tabla `metadata` y `files`

**Nota:** El error `MissingPluginException` es **engañoso**. Los métodos existen pero fallan porque las tablas no existen, y el error se captura y reporta como plugin faltante en Flutter.

---

## 📋 Esquema Completo Requerido

Basado en el análisis del código, estas son **TODAS las tablas necesarias**:

### **1. Tabla `metadata`** (Metadata de tracks)
```sql
CREATE TABLE IF NOT EXISTS metadata (
    id TEXT PRIMARY KEY NOT NULL,
    track_name TEXT NOT NULL,
    artist_name TEXT NOT NULL,
    album_name TEXT NOT NULL,
    album_artist TEXT,
    isrc TEXT,
    duration_ms INTEGER DEFAULT 0,
    track_number INTEGER DEFAULT 0,
    total_tracks INTEGER DEFAULT 0,
    disc_number INTEGER DEFAULT 1,
    total_discs INTEGER DEFAULT 1,
    release_date TEXT,
    genre TEXT,
    composer TEXT,
    label TEXT,
    copyright TEXT,
    spotify_id TEXT,
    cover_url TEXT,
    cover_path TEXT
);

CREATE INDEX IF NOT EXISTS idx_metadata_spotify_id ON metadata(spotify_id);
CREATE INDEX IF NOT EXISTS idx_metadata_isrc ON metadata(isrc);
CREATE INDEX IF NOT EXISTS idx_metadata_track_artist ON metadata(track_name, artist_name);
```

### **2. Tabla `files`** (Archivos de audio)
```sql
CREATE TABLE IF NOT EXISTS files (
    id TEXT PRIMARY KEY NOT NULL,
    metadata_id TEXT NOT NULL,
    file_path TEXT UNIQUE NOT NULL,
    source TEXT NOT NULL CHECK(source IN ('download', 'local_scan')),
    format TEXT,
    bitrate INTEGER DEFAULT 0,
    bit_depth INTEGER DEFAULT 0,
    sample_rate INTEGER DEFAULT 0,
    downloaded_at TEXT,
    scanned_at TEXT,
    file_mod_time INTEGER DEFAULT 0,
    saf_file_name TEXT,
    FOREIGN KEY (metadata_id) REFERENCES metadata(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_files_metadata_id ON files(metadata_id);
CREATE INDEX IF NOT EXISTS idx_files_source ON files(source);
CREATE INDEX IF NOT EXISTS idx_files_file_path ON files(file_path);
```

### **3. Tabla `application_state`** (Configuración de la app)
```sql
CREATE TABLE IF NOT EXISTS application_state (
    key TEXT PRIMARY KEY NOT NULL,
    value TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
```

### **4. Tabla `favorites`** (Favoritos/Likes)
```sql
CREATE TABLE IF NOT EXISTS favorites (
    item_id TEXT PRIMARY KEY NOT NULL,
    type TEXT NOT NULL,
    name TEXT NOT NULL,
    secondary_name TEXT,
    cover_url TEXT,
    added_at TEXT NOT NULL,
    item_json TEXT,
    cover_path TEXT,
    audio_path TEXT,
    match_key TEXT,
    codec TEXT,
    bit_depth INTEGER,
    sample_rate INTEGER
);

CREATE INDEX IF NOT EXISTS idx_favorites_type ON favorites(type);
```

### **5. Tabla `collections`** (Playlists/Colecciones)
```sql
CREATE TABLE IF NOT EXISTS collections (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    type TEXT,
    cover_path TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    custom_json TEXT,
    item_json TEXT
);
```

### **6. Tabla `collection_items`** (Items en colecciones)
```sql
CREATE TABLE IF NOT EXISTS collection_items (
    collection_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    metadata_id TEXT,
    item_json TEXT,
    added_at TEXT NOT NULL,
    position INTEGER DEFAULT 0,
    PRIMARY KEY (collection_id, item_id),
    FOREIGN KEY (collection_id) REFERENCES collections(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_collection_items_item_id ON collection_items(item_id);
```

### **7. Tabla `play_history`** (Historial de reproducción)
```sql
CREATE TABLE IF NOT EXISTS play_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    track_id TEXT NOT NULL,
    track_name TEXT NOT NULL,
    artist_name TEXT NOT NULL,
    album_name TEXT,
    played_at TEXT NOT NULL,
    duration_ms INTEGER DEFAULT 0,
    percentage INTEGER DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_play_history_played_at ON play_history(played_at DESC);
CREATE INDEX IF NOT EXISTS idx_play_history_track_id ON play_history(track_id);
```

### **8. Tabla `play_aggregates`** (Contadores de reproducción)
```sql
CREATE TABLE IF NOT EXISTS play_aggregates (
    item_id TEXT PRIMARY KEY NOT NULL,
    type TEXT NOT NULL CHECK(type IN ('track', 'album', 'artist')),
    play_count INTEGER DEFAULT 0,
    last_played_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_play_aggregates_type ON play_aggregates(type);
```

### **9. Tabla `secret_counters`** (Logros/Secretos)
```sql
CREATE TABLE IF NOT EXISTS secret_counters (
    key TEXT PRIMARY KEY NOT NULL,
    value INTEGER DEFAULT 0
);
```

### **10. Tabla `secret_unlocks`** (Logros desbloqueados)
```sql
CREATE TABLE IF NOT EXISTS secret_unlocks (
    key TEXT PRIMARY KEY NOT NULL,
    unlocked_at TEXT NOT NULL
);
```

### **11. Tabla `download_queue`** (Cola de descargas)
```sql
CREATE TABLE IF NOT EXISTS download_queue (
    id TEXT PRIMARY KEY NOT NULL,
    track_json TEXT NOT NULL,
    item_json TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'downloading', 'completed', 'failed')),
    progress REAL DEFAULT 0.0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    added_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_download_queue_status ON download_queue(status);
```

### **12. Tabla `recent_access`** (Accesos recientes)
```sql
CREATE TABLE IF NOT EXISTS recent_access (
    id TEXT PRIMARY KEY NOT NULL,
    item_json TEXT NOT NULL,
    type TEXT DEFAULT 'recent',
    accessed_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_recent_access_accessed_at ON recent_access(accessed_at DESC);
```

### **13. Tabla `hidden_recent_downloads`** (Descargas ocultas)
```sql
CREATE TABLE IF NOT EXISTS hidden_recent_downloads (
    download_id TEXT PRIMARY KEY NOT NULL
);
```

### **14. Tabla `isrc_cache`** (Caché ISRC) 
*(Ya existe en `isrc_cache.go:18-28`)*
```sql
CREATE TABLE IF NOT EXISTS isrc_cache (
    isrc TEXT PRIMARY KEY,
    genre TEXT NOT NULL DEFAULT '',
    album_artist TEXT NOT NULL DEFAULT '',
    fetched_at INTEGER NOT NULL
);
```

---

## 🔧 Solución Propuesta

### **Opción 1: Función de Migración Manual (RECOMENDADA)**

Crear una nueva función `ensureDatabaseSchema()` que se llame después de abrir la conexión:

```go
// En database.go, después de InitMasterDatabase()

func ensureDatabaseSchema(db *sql.DB) error {
    schema := `
    -- Metadata
    CREATE TABLE IF NOT EXISTS metadata (
        id TEXT PRIMARY KEY NOT NULL,
        track_name TEXT NOT NULL,
        artist_name TEXT NOT NULL,
        album_name TEXT NOT NULL,
        album_artist TEXT,
        isrc TEXT,
        duration_ms INTEGER DEFAULT 0,
        track_number INTEGER DEFAULT 0,
        total_tracks INTEGER DEFAULT 0,
        disc_number INTEGER DEFAULT 1,
        total_discs INTEGER DEFAULT 1,
        release_date TEXT,
        genre TEXT,
        composer TEXT,
        label TEXT,
        copyright TEXT,
        spotify_id TEXT,
        cover_url TEXT,
        cover_path TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_metadata_spotify_id ON metadata(spotify_id);
    CREATE INDEX IF NOT EXISTS idx_metadata_isrc ON metadata(isrc);
    CREATE INDEX IF NOT EXISTS idx_metadata_track_artist ON metadata(track_name, artist_name);

    -- Files
    CREATE TABLE IF NOT EXISTS files (
        id TEXT PRIMARY KEY NOT NULL,
        metadata_id TEXT NOT NULL,
        file_path TEXT UNIQUE NOT NULL,
        source TEXT NOT NULL CHECK(source IN ('download', 'local_scan')),
        format TEXT,
        bitrate INTEGER DEFAULT 0,
        bit_depth INTEGER DEFAULT 0,
        sample_rate INTEGER DEFAULT 0,
        downloaded_at TEXT,
        scanned_at TEXT,
        file_mod_time INTEGER DEFAULT 0,
        saf_file_name TEXT,
        FOREIGN KEY (metadata_id) REFERENCES metadata(id) ON DELETE CASCADE
    );
    CREATE INDEX IF NOT EXISTS idx_files_metadata_id ON files(metadata_id);
    CREATE INDEX IF NOT EXISTS idx_files_source ON files(source);
    CREATE INDEX IF NOT EXISTS idx_files_file_path ON files(file_path);

    -- Application State
    CREATE TABLE IF NOT EXISTS application_state (
        key TEXT PRIMARY KEY NOT NULL,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );

    -- [... resto de tablas ...]
    `;

    _, err := db.Exec(schema)
    return err
}
```

Luego modificar `InitMasterDatabase()`:

```go
func InitMasterDatabase(path string) error {
    masterDBMu.Lock()
    defer masterDBMu.Unlock()

    if masterDB != nil {
        masterDB.Close()
    }

    db, err := sql.Open("sqlite3", path)
    if err != nil {
        return fmt.Errorf("failed to open database: %w", err)
    }

    // Optimizaciones
    _, _ = db.Exec("PRAGMA journal_mode=WAL")
    _, _ = db.Exec("PRAGMA synchronous=NORMAL")
    _, _ = db.Exec("PRAGMA cache_size=-64000")
    _, _ = db.Exec("PRAGMA busy_timeout=5000")
    _, _ = db.Exec("PRAGMA foreign_keys=ON") // IMPORTANTE!

    // CREAR ESQUEMA
    if err := ensureDatabaseSchema(db); err != nil {
        db.Close()
        return fmt.Errorf("failed to create schema: %w", err)
    }

    masterDB = db
    dbPath = path
    return nil
}
```

### **Opción 2: Archivo SQL Separado**

Crear `go_backend_spotiflac/schema.sql` con todas las tablas y leerlo en tiempo de ejecución.

### **Opción 3: Sistema de Migraciones**

Usar una biblioteca como `golang-migrate/migrate` para gestionar versiones del esquema.

---

## ✅ Checklist de Implementación

- [ ] Crear función `ensureDatabaseSchema()` con todas las 14 tablas
- [ ] Modificar `InitMasterDatabase()` para llamar a `ensureDatabaseSchema()`
- [ ] Agregar `PRAGMA foreign_keys=ON` para integridad referencial
- [ ] Agregar manejo de errores detallado en la creación del esquema
- [ ] Probar con base de datos nueva (no debe fallar)
- [ ] Probar con base de datos existente (debe ser idempotente)
- [ ] Verificar que `loadAppSettings` funciona después de la migración
- [ ] Verificar que `getDownloadEntryBySpotifyID` funciona
- [ ] Verificar que `findDownloadEntryByTrackAndArtist` funciona
- [ ] Agregar logs de debug para confirmar creación de tablas

---

## 🎯 Resultado Esperado

Después de la implementación:

1. ✅ No más errores `no such table: application_state`
2. ✅ No más `MissingPluginException` para métodos implementados
3. ✅ Base de datos se inicializa correctamente en el primer uso
4. ✅ Esquema persiste entre reinicios de la aplicación
5. ✅ Todas las funcionalidades de BD funcionan

---

## 📝 Notas Adicionales

### Sobre MissingPluginException

Este error es **engañoso** en este caso. Los logs muestran:
```
MissingPluginException(No implementation found for method getDownloadEntryBySpotifyID on channel com.zarz.spotiflac/backend)
```

Pero el método **SÍ está implementado**. Lo que sucede es:
1. Flutter llama al método via `MethodChannel`
2. El método ejecuta en Go
3. La consulta SQL falla porque la tabla no existe
4. Go retorna un error
5. Flutter interpreta el error como "método no encontrado"

**Solución:** Arreglar el esquema de BD eliminará estos errores.

### Sobre la Arquitectura

El proyecto usa una arquitectura híbrida:
- **Desktop:** HTTP RPC via `cmd/server/main.go` (dispatcher)
- **Mobile:** MethodChannel directo a funciones exportadas en `exports.go`

Ambas rutas convergen en las mismas funciones de `database.go`, por lo que arreglar el esquema soluciona ambos casos.

---

## 🔗 Archivos Relacionados

1. `go_backend_spotiflac/database.go` - Funciones de BD
2. `go_backend_spotiflac/exports.go` - Exportaciones para gomobile
3. `go_backend_spotiflac/cmd/server/main.go` - Servidor HTTP/RPC
4. `lib/services/platform_bridge.dart` - Puente Flutter↔Go
5. `lib/providers/settings_provider.dart` - Usa `loadAppSettings`
6. `lib/services/history_database.dart` - Usa métodos de BD

---

**Fin del Diagnóstico**
