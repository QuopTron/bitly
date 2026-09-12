package gobackend

import (
	"encoding/json"
	"log"

	"github.com/zarz/bitly/go_backend/internal/bundled_extensions"
	"github.com/zarz/bitly/go_backend/internal/extensions"
)

// =========================================================================
// EXTENSIONS — System management
// =========================================================================

func InitExtensionSystem(payload string) string {
	var params struct {
		ExtensionsDir string `json:"extensions_dir"`
		DataDir       string `json:"data_dir"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}

	// Don't clobber an already-populated extRegistry: InitGlobalState loads
	// el embedded extensions WITH signed-sesión configuración attached. If we
	// replaced it here, the Cloudflare verification flow would find no
	// sandbox/session and no auth URL would ever be returned.
	er := getExtRegistry()
	if er == nil || er.Runtime().Count() == 0 {
		er = extensions.NewRegistryBestEffort(params.ExtensionsDir)
		setExtRegistry(er)
	}
	// Actualización silenciosa contra el registry empaquetado: refresca las
	// extensiones viejas que viven en el directorio que usa la app (en
	// escritorio suele ser la carpeta de assets junto al ejecutable). Si el
	// directorio no es escribible, se ignora sin afectar la carga.
	if actualizadas := bundled_extensions.SincronizarConDisco(params.ExtensionsDir); len(actualizadas) > 0 {
		log.Printf("[extensions] %d extensiones actualizadas en %s: %v",
			len(actualizadas), params.ExtensionsDir, actualizadas)
	}
	// Load any on-disk extensions (subdir layout) into the existing registry.
	_ = extensions.LoadDirExtensionsInto(er, params.ExtensionsDir, params.DataDir)
	// Re-apply stored settings (OAuth tokens, credentials) to extensions whose
	// sandbox just finished loading — a startup push may have raced it.
	replicarAjustesExtensiones()
	data, _ := json.Marshal(er.List())
	return string(data)
}

func GetInstalledExtensions() string {
	er := getExtRegistry()
	if er == nil {
		return `[]`
	}
	data, _ := json.Marshal(er.List())
	return string(data)
}

// GetBundledExtensions returns the list of bundled (embedded) extensions.
func GetBundledExtensions() string {
	if len(bundledExts) == 0 {
		return `[]`
	}
	data, _ := json.Marshal(bundledExts)
	return string(data)
}

// SearchFilterConfig is the Flutter-facing shape of one search category bubble.
