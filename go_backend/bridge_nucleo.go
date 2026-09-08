// Bridge de export para gomobile — nucleo.
//
// gomobile bind no puede bindear paquetes bajo internal/ (el gobind
// generado vive en un modulo temporal 'gobind' fuera del arbol del
// modulo, y Go prohibe importar internal/ desde afuera). Antes de la
// reorganizacion este paquete vivia en la raiz; ahora la raiz solo
// re-exporta internal/gobackend para que el CI de Android/iOS siga
// generando el AAR/xcframework con la misma API (gobackend.Gobackend).
// No editar a mano los wrappers generados.

package gobackend

import gobackend "github.com/zarz/bitly/go_backend/internal/gobackend"

// AddToQueue re-exportado desde internal/gobackend.
func AddToQueue(payload string) string {
	return gobackend.AddToQueue(payload)
}

// ClearQueue re-exportado desde internal/gobackend.
func ClearQueue() string {
	return gobackend.ClearQueue()
}

// CloseBackend re-exportado desde internal/gobackend.
func CloseBackend() {
	gobackend.CloseBackend()
}

// DumpGoroutines re-exportado desde internal/gobackend.
func DumpGoroutines(path string) string {
	return gobackend.DumpGoroutines(path)
}

// GetBuildInfo re-exportado desde internal/gobackend.
func GetBuildInfo() string {
	return gobackend.GetBuildInfo()
}

// GetCallbackID re-exportado desde internal/gobackend.
func GetCallbackID() string {
	return gobackend.GetCallbackID()
}

// GetPlatform re-exportado desde internal/gobackend.
func GetPlatform() string {
	return gobackend.GetPlatform()
}

// GetPlayQueue re-exportado desde internal/gobackend.
func GetPlayQueue() string {
	return gobackend.GetPlayQueue()
}

// InitBackend re-exportado desde internal/gobackend.
func InitBackend() error {
	return gobackend.InitBackend()
}

// InitExtensionSystem re-exportado desde internal/gobackend.
func InitExtensionSystem(payload string) string {
	return gobackend.InitExtensionSystem(payload)
}

// InitGlobalState re-exportado desde internal/gobackend.
func InitGlobalState() string {
	return gobackend.InitGlobalState()
}

// IsMobile re-exportado desde internal/gobackend.
func IsMobile() bool {
	return gobackend.IsMobile()
}

// Ping re-exportado desde internal/gobackend.
func Ping() string {
	return gobackend.Ping()
}

// RemoveFromQueue re-exportado desde internal/gobackend.
func RemoveFromQueue(position int) string {
	return gobackend.RemoveFromQueue(position)
}

// ReorderQueue re-exportado desde internal/gobackend.
func ReorderQueue(payload string) string {
	return gobackend.ReorderQueue(payload)
}

// ResetDatabase re-exportado desde internal/gobackend.
func ResetDatabase() string {
	return gobackend.ResetDatabase()
}

// SetAppDataDir re-exportado desde internal/gobackend.
func SetAppDataDir(appDataDir string) {
	gobackend.SetAppDataDir(appDataDir)
}

// SetFlutterCallback re-exportado desde internal/gobackend.
func SetFlutterCallback(id string) {
	gobackend.SetFlutterCallback(id)
}

// SetMemoryLimitMB re-exportado desde internal/gobackend.
func SetMemoryLimitMB(n int) string {
	return gobackend.SetMemoryLimitMB(n)
}
