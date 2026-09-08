// Bridge de export para gomobile — descargas.
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

// CancelDownload re-exportado desde internal/gobackend.
func CancelDownload(itemID string) bool {
	return gobackend.CancelDownload(itemID)
}

// DownloadBatch re-exportado desde internal/gobackend.
func DownloadBatch(tracksJSON string) string {
	return gobackend.DownloadBatch(tracksJSON)
}

// DownloadByStrategy re-exportado desde internal/gobackend.
func DownloadByStrategy(payload string) string {
	return gobackend.DownloadByStrategy(payload)
}

// DownloadItem re-exportado desde internal/gobackend.
func DownloadItem(payload string) string {
	return gobackend.DownloadItem(payload)
}

// DownloadTrack re-exportado desde internal/gobackend.
func DownloadTrack(requestJSON string) string {
	return gobackend.DownloadTrack(requestJSON)
}

// EstimateTrackFileSize re-exportado desde internal/gobackend.
func EstimateTrackFileSize(payload string) string {
	return gobackend.EstimateTrackFileSize(payload)
}

// ExtensionDownload re-exportado desde internal/gobackend.
func ExtensionDownload(payload string) string {
	return gobackend.ExtensionDownload(payload)
}

// GetAllDownloadProgress re-exportado desde internal/gobackend.
func GetAllDownloadProgress() string {
	return gobackend.GetAllDownloadProgress()
}

// GetDownloadProgress re-exportado desde internal/gobackend.
func GetDownloadProgress() string {
	return gobackend.GetDownloadProgress()
}

// InitItemProgress re-exportado desde internal/gobackend.
func InitItemProgress(payload string) string {
	return gobackend.InitItemProgress(payload)
}

// RescueBatch re-exportado desde internal/gobackend.
func RescueBatch(tracksJSON string) string {
	return gobackend.RescueBatch(tracksJSON)
}

// RescueTrack re-exportado desde internal/gobackend.
func RescueTrack(payload string) string {
	return gobackend.RescueTrack(payload)
}

// SetBackendConfig re-exportado desde internal/gobackend.
func SetBackendConfig(payload string) string {
	return gobackend.SetBackendConfig(payload)
}

// SetDownloadDirectory re-exportado desde internal/gobackend.
func SetDownloadDirectory(payload string) string {
	return gobackend.SetDownloadDirectory(payload)
}

// SetDownloadProviderPriority re-exportado desde internal/gobackend.
func SetDownloadProviderPriority(payload string) string {
	return gobackend.SetDownloadProviderPriority(payload)
}

// SetStreamCacheMaxMb re-exportado desde internal/gobackend.
func SetStreamCacheMaxMb(payload string) string {
	return gobackend.SetStreamCacheMaxMb(payload)
}
