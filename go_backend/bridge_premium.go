// Bridge de export para gomobile — premium.
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

// CheckDownloadAllowed re-exportado desde internal/gobackend.
func CheckDownloadAllowed() string {
	return gobackend.CheckDownloadAllowed()
}

// GetPlayCount re-exportado desde internal/gobackend.
func GetPlayCount(trackID string) string {
	return gobackend.GetPlayCount(trackID)
}

// GetPlayHistory re-exportado desde internal/gobackend.
func GetPlayHistory(limit int) string {
	return gobackend.GetPlayHistory(limit)
}

// GetPremiumStatus re-exportado desde internal/gobackend.
func GetPremiumStatus() string {
	return gobackend.GetPremiumStatus()
}

// ScrobbleTrack re-exportado desde internal/gobackend.
func ScrobbleTrack(payload string) string {
	return gobackend.ScrobbleTrack(payload)
}

// SetPremiumGithubToken re-exportado desde internal/gobackend.
func SetPremiumGithubToken(payload string) string {
	return gobackend.SetPremiumGithubToken(payload)
}

// SetPremiumStatus re-exportado desde internal/gobackend.
func SetPremiumStatus(payload string) string {
	return gobackend.SetPremiumStatus(payload)
}

// SetupScrobbling re-exportado desde internal/gobackend.
func SetupScrobbling(configJSON string) bool {
	return gobackend.SetupScrobbling(configJSON)
}

// UpdateNowPlaying re-exportado desde internal/gobackend.
func UpdateNowPlaying(payload string) string {
	return gobackend.UpdateNowPlaying(payload)
}

// ValidatePremiumCode re-exportado desde internal/gobackend.
func ValidatePremiumCode(payload string) string {
	return gobackend.ValidatePremiumCode(payload)
}
