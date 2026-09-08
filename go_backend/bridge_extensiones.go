// Bridge de export para gomobile — extensiones.
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

// GetBundledExtensions re-exportado desde internal/gobackend.
func GetBundledExtensions() string {
	return gobackend.GetBundledExtensions()
}

// GetInstalledExtensions re-exportado desde internal/gobackend.
func GetInstalledExtensions() string {
	return gobackend.GetInstalledExtensions()
}

// GetPendingVerificationUrl re-exportado desde internal/gobackend.
func GetPendingVerificationUrl(payload string) string {
	return gobackend.GetPendingVerificationUrl(payload)
}

// InvokeExtensionAction re-exportado desde internal/gobackend.
func InvokeExtensionAction(payload string) string {
	return gobackend.InvokeExtensionAction(payload)
}

// LoadExtensionsFromDir re-exportado desde internal/gobackend.
func LoadExtensionsFromDir(payload string) string {
	return gobackend.LoadExtensionsFromDir(payload)
}

// ReinitializeExtension re-exportado desde internal/gobackend.
func ReinitializeExtension(payload string) string {
	return gobackend.ReinitializeExtension(payload)
}

// SetExtensionSettings re-exportado desde internal/gobackend.
func SetExtensionSettings(payload string) string {
	return gobackend.SetExtensionSettings(payload)
}

// StoreSessionToken re-exportado desde internal/gobackend.
func StoreSessionToken(payload string) string {
	return gobackend.StoreSessionToken(payload)
}

// TriggerExtensionVerification re-exportado desde internal/gobackend.
func TriggerExtensionVerification(payload string) string {
	return gobackend.TriggerExtensionVerification(payload)
}
