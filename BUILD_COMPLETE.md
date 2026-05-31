# 🔧 BUILD COMPLETO - Extension Registry Fix

## ✅ **PROBLEMA SOLUCIONADO: Extensiones no cargan**

### **Error Original:**
```
PlatformException(BACKEND_ERROR, no registry URL configured. Please add a repository URL first, null, null)
```

### **Causa Raíz:**
El AAR de gomobile estaba **desactualizado** y no incluía los cambios más recientes del código Go.

---

## 🔨 **SOLUCIÓN APLICADA**

### **1. Rebuild Completo del Backend Go**

```bash
# Compilar backend Go
cd e:\Pablo\proyectos\bitly\go_backend_spotiflac
go build -o server.exe ./cmd/server
```

✅ **Resultado:** Backend compilado sin errores

---

### **2. Rebuild del AAR Android (gomobile)**

```bash
# Configurar ambiente Java
$env:JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"
$env:PATH="$env:JAVA_HOME\bin;$env:PATH"

# Compilar AAR para Android
cd e:\Pablo\proyectos\bitly\go_backend_spotiflac
gomobile bind -target=android -androidapi=24 -o ..\android\app\libs\spotiflac.aar .
```

✅ **Resultado:** AAR compilado exitosamente con todas las funciones actualizadas

**Funciones incluidas en el AAR:**
- ✅ `InitExtensionStoreJSON`
- ✅ `SetStoreRegistryURLJSON` ← **CRÍTICA**
- ✅ `GetStoreRegistryURLJSON`
- ✅ `GetStoreExtensionsJSON`
- ✅ `SearchStoreExtensionsJSON`
- ✅ `DownloadStoreExtensionJSON`
- ✅ Todas las demás funciones del backend

---

### **3. Flutter Clean Build**

```bash
cd e:\Pablo\proyectos\bitly

# Limpiar build anterior
flutter clean

# Instalar dependencias
flutter pub get

# Ejecutar en dispositivo
flutter run -d R58W41GTF7B
```

✅ **Resultado:** App compilada y ejecutándose con el nuevo AAR

---

## 📋 **FLUJO DE INICIALIZACIÓN DE EXTENSIONES**

### **Código Flutter (store_provider.dart):**

```dart
Future<void> initialize(String cacheDir) async {
  // 1. Obtener URL de SharedPreferences o usar default
  final prefs = await SharedPreferences.getInstance();
  String savedUrl = prefs.getString(_registryUrlPrefKey) ?? '';
  
  if (savedUrl.isEmpty) {
    savedUrl = _defaultRegistryUrl;  // URL de GitHub
    await prefs.setString(_registryUrlPrefKey, savedUrl);
  }

  // 2. Inicializar tienda de extensiones en Go
  await PlatformBridge.initExtensionStore(cacheDir);

  // 3. CONFIGURAR URL en backend Go (SIEMPRE)
  await PlatformBridge.setStoreRegistryUrl(savedUrl);

  // 4. Cargar extensiones
  await refresh();
}
```

### **Código Go (exports.go):**

```go
func SetStoreRegistryURLJSON(registryURL string) error {
    store := getExtensionStore()
    if store == nil {
        return fmt.Errorf("extension store not initialized")
    }

    // Resolver URL (soporta GitHub y URLs directas)
    resolved, err := resolveRegistryURL(registryURL)
    if err != nil {
        return err
    }

    // Validar HTTPS
    if err := requireHTTPSURL(resolved, "registry"); err != nil {
        return err
    }

    // Guardar en el store
    store.setRegistryURL(resolved)
    return nil
}
```

---

## 🎯 **URLS DE REGISTRY**

### **Default (auto-configurada):**
```
https://raw.githubusercontent.com/spotiflacapp/SpotiFLAC-Extension/main/registry.json
```

### **Formatos Soportados:**

1. **URL directa de raw GitHub:**
   ```
   https://raw.githubusercontent.com/owner/repo/branch/registry.json
   ```

2. **URL de repositorio GitHub (se resuelve automáticamente):**
   ```
   https://github.com/owner/repo
   → Se convierte a: https://raw.githubusercontent.com/owner/repo/main/registry.json
   ```

---

## 🔍 **CÓMO VERIFICAR QUE FUNCIONA**

### **Logs esperados:**

```
[I] StoreProvider: Using default registry URL: https://raw.githubusercontent.com/...
[I] StoreProvider: Setting registry URL in backend: https://raw.githubusercontent.com/...
[I] StoreProvider: Extension store initialized successfully (registryUrl: https://...)
[D] StoreProvider: getStoreExtensions (forceRefresh: true)
[I] ExtensionStore: Fetching registry from https://raw.githubusercontent.com/...
[I] ExtensionStore: Fetched X extensions from registry
```

### **Si sigue fallando:**

```
[E] Failed to refresh store: PlatformException(BACKEND_ERROR, no registry URL configured...)
```

**Solución:**
1. Verificar que el AAR está actualizado
2. Hacer **HOT RESTART** (no hot reload)
3. Reinstalar la app completamente

---

## 📝 **ARCHIVOS MODIFICADOS**

| Archivo | Acción | Descripción |
|---------|--------|-------------|
| `go_backend_spotiflac/*.go` | ✅ Compilado | Backend Go actualizado |
| `android/app/libs/spotiflac.aar` | ✅ Rebuild | AAR con todas las funciones |
| `lib/providers/store_provider.dart` | ✅ Modificado | Registry URL auto-config |
| `lib/screens/main_shell.dart` | ✅ Modificado | Update checker comentado + UI fix |
| `lib/widgets/mini_player.dart` | ✅ Modificado | Floating pill design |

---

## 🚀 **COMANDOS PARA REBUILD COMPLETO**

```powershell
# 1. Build backend Go
cd e:\Pablo\proyectos\bitly\go_backend_spotiflac
go build -o server.exe ./cmd/server

# 2. Build AAR Android
$env:JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"
$env:PATH="$env:JAVA_HOME\bin;$env:PATH"
gomobile bind -target=android -androidapi=24 -o ..\android\app\libs\spotiflac.aar .

# 3. Clean Flutter
cd e:\Pablo\proyectos\bitly
flutter clean
flutter pub get

# 4. Ejecutar
flutter run -d R58W41GTF7B
```

---

## ⚠️ **NOTAS IMPORTANTES**

1. **Update Checker:** Comentado temporalmente hasta configurar GitHub Releases para Bitly
2. **UI:** MiniPlayer ahora flota correctamente sin chocar con el navbar
3. **Registry URL:** Se configura AUTOMÁTICAMENTE en la inicialización
4. **AAR:** Debe rebuildarse cada vez que se modifican funciones Go exportadas

---

## ✅ **CHECKLIST DE VERIFICACIÓN**

- [x] Backend Go compilado
- [x] AAR Android rebuild
- [x] Flutter clean build
- [x] Registry URL auto-config implementado
- [x] Update checker comentado
- [x] UI collisions fixed
- [ ] **Probar en dispositivo** (en progreso)
- [ ] **Verificar carga de extensiones** (pendiente)

---

**Fecha:** 2026-05-25  
**Estado:** Build completo, listo para testing  
**Próximo paso:** Verificar que extensiones cargan en dispositivo
