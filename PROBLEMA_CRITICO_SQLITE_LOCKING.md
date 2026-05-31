# 🚨 PROBLEMA CRÍTICO: SQLite Locking Protocol

## 📋 Problema Encontrado

**Error:** `sqlite3: locking protocol`

**Aparece en:**
```log
I/flutter: [W] Go loadAppSettings failed, fallback: PlatformException(BACKEND_ERROR, sqlite3: locking protocol, null, null)
I/flutter: [W] Go getCount failed, fallback: PlatformException(BACKEND_ERROR, sqlite3: locking protocol, null, null)
I/flutter: [W] Go getAll failed, fallback: PlatformException(BACKEND_ERROR, sqlite3: locking protocol, null, null)
I/flutter: [W] Go loadSnapshot failed, fallback: PlatformException(BACKEND_ERROR, sqlite3: locking protocol, null, null)
I/flutter: [W] Go saveAppSettings failed: PlatformException(BACKEND_ERROR, sqlite3: locking protocol, null, null)
```

---

## 🔍 Causa Raíz

**Flutter y Go están intentando acceder a la misma base de datos simultáneamente**, causando un deadlock/locking conflict.

### El Problema:

1. ✅ Flutter crea la DB con schema (correcto)
2. ✅ Go backend abre la misma DB (correcto)
3. ❌ **PERO:** Flutter NO cierra su conexión
4. ❌ **Flutter mantiene la DB abierta** via `MasterDatabase.instance.database`
5. ❌ **Go intenta escribir** → `sqlite3: locking protocol` error

### Conflicto de Acceso Concurrente:

```
Flutter SQLite Connection (sqflite)
    ↓ (mantiene conexión abierta)
    ↓
bitly_master.db ← LOCKED
    ↑
    ↑ (intenta acceder)
Go Backend SQLite Connection (go-sqlite3)
    → ERROR: locking protocol
```

---

## ✅ Solución

### Opción 1: Usar WAL Mode (Ya configurado pero no funciona bien en Android 9)

El código Go ya tiene:
```go
_, _ = db.Exec("PRAGMA journal_mode=WAL")
```

Pero en Android 9 el WAL mode tiene problemas de compatibilidad.

### Opción 2: Flutter NO debe mantener conexión abierta ❌

**Problema:** Flutter necesita la DB para sus propias operaciones.

### Opción 3: **SOLUCIÓN CORRECTA - Usar SOLO Go Backend para DB** ✅

**La solución real es:**
1. Flutter NO debe acceder directamente a SQLite
2. TODO el acceso a DB debe ser vía Go backend (RPC)
3. Flutter solo llama a métodos Go para leer/escribir datos

Pero esto requiere refactorizar TODO el código de Flutter...

### Opción 4: **FIX RÁPIDO - Cerrar conexión Flutter después de crear schema** ✅

**Este es el fix más rápido:**

1. Flutter crea el schema
2. **Flutter CIERRA la conexión**
3. Go abre la DB
4. Flutter usa SOLO el backend Go para acceder a datos

---

## 🔧 Implementación del Fix Rápido

### 1. Modificar `lib/main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (!Platform.isAndroid && !Platform.isIOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await PlatformBridge.initDesktopBackend();
  }

  // CRITICAL: Initialize Flutter SQLite FIRST to create schema
  debugPrint('[Init] Initializing Flutter SQLite database with schema...');
  final db = await MasterDatabase.instance.database;
  debugPrint('[Init] ✅ Flutter SQLite database schema created');
  
  // ✅ NEW: Close Flutter connection to prevent locking
  if (Platform.isAndroid || Platform.isIOS) {
    await db.close();
    debugPrint('[Init] ✅ Flutter SQLite connection closed (Go will handle all DB access)');
  }

  // THEN initialize Go backend (opens existing DB)
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final dbPath = '${docsDir.path}/bitly_master.db';
      final ytDlpPath = '${docsDir.path}/yt-dlp';

      debugPrint('[Init] Initializing Go backend...');
      await PlatformBridge.invoke('initGoBackend', {
        'db_path': dbPath,
        'ytdlp_path': ytDlpPath,
      });
      debugPrint('[Init] ✅ Go backend initialized successfully');
    } catch (e) {
      debugPrint('[Init] ⚠️ Failed to initialize Go backend: $e');
    }
  }

  final runtimeProfile = await _resolveRuntimeProfile();
  _configureImageCache(runtimeProfile);

  runApp(
    ProviderScope(
      child: _EagerInitialization(
        child: SpotiFLACApp(
          disableOverscrollEffects: runtimeProfile.disableOverscrollEffects,
        ),
      ),
    ),
  );
}
```

### 2. Modificar `lib/services/master_database.dart`

Agregar método para cerrar conexión:

```dart
class MasterDatabase {
  static final MasterDatabase instance = MasterDatabase._();
  Database? _database;

  // ... código existente ...

  /// Close the database connection (use when Go backend will handle all access)
  Future<void> closeConnection() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _log.i('Master database connection closed');
    }
  }
}
```

### 3. Actualizar main.dart para usar el nuevo método:

```dart
// Close Flutter connection to prevent locking
if (Platform.isAndroid || Platform.isIOS) {
  await MasterDatabase.instance.closeConnection();
  debugPrint('[Init] ✅ Flutter SQLite connection closed');
}
```

---

## 🎯 Resultado Esperado

### Antes (con locking):
```log
❌ [W] Go loadAppSettings failed: sqlite3: locking protocol
❌ [W] Go getCount failed: sqlite3: locking protocol
❌ [W] Go saveAppSettings failed: sqlite3: locking protocol
```

### Después (sin locking):
```log
✅ [Init] Flutter SQLite database schema created
✅ [Init] Flutter SQLite connection closed
✅ [Init] Go backend initialized successfully
✅ Go loadAppSettings: success
✅ Bootstrap: Installed 9 extensions
```

---

## ⚠️ Limitaciones

**IMPORTANTE:** Después de este fix, **Flutter NO podrá usar MasterDatabase directamente**. 

Cualquier código Flutter que intente:
```dart
await MasterDatabase.instance.database.query('...')
```

**FALLARÁ** porque la conexión está cerrada.

**Solución:** Usar siempre el backend Go:
```dart
await PlatformBridge.invoke('getDownloadHistory', {...})
```

---

## 📝 Archivos a Modificar

1. ✅ `lib/main.dart` - Cerrar conexión después de crear schema
2. ✅ `lib/services/master_database.dart` - Agregar método `closeConnection()`

---

## 🚀 Testing

```bash
flutter clean
flutter pub get
cd android && ./gradlew clean && cd ..
flutter run -d emulator-5554 --verbose
```

**Logs esperados:**
```log
✅ [Init] Initializing Flutter SQLite database with schema...
✅ [Init] ✅ Flutter SQLite database schema created
✅ [Init] ✅ Flutter SQLite connection closed
✅ [Init] Initializing Go backend...
✅ I/NativeBridge: Go backend database initialized
✅ I/NativeBridge: Bootstrap result: Installed 9 extensions
```

**NO debe aparecer:**
```log
❌ sqlite3: locking protocol
```

---

**Prioridad:** 🔴 CRÍTICA  
**Impacto:** Bloquea TODA la funcionalidad de la app  
**Fix:** ✅ Listo para implementar
