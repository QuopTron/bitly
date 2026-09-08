// Bridge de export para gomobile — sesiones.
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

// ClearSignedSession re-exportado desde internal/gobackend.
func ClearSignedSession(extensionID string) string {
	return gobackend.ClearSignedSession(extensionID)
}

// CompleteSignedSessionGrant re-exportado desde internal/gobackend.
func CompleteSignedSessionGrant(payload string) string {
	return gobackend.CompleteSignedSessionGrant(payload)
}

// ExchangeSessionGrant re-exportado desde internal/gobackend.
func ExchangeSessionGrant(payload string) string {
	return gobackend.ExchangeSessionGrant(payload)
}

// ExchangeYoutubeOauth re-exportado desde internal/gobackend.
func ExchangeYoutubeOauth(payload string) string {
	return gobackend.ExchangeYoutubeOauth(payload)
}

// GetSessionAuthURL re-exportado desde internal/gobackend.
func GetSessionAuthURL(extensionID string) string {
	return gobackend.GetSessionAuthURL(extensionID)
}

// GetSessionStatus re-exportado desde internal/gobackend.
func GetSessionStatus(extensionID string) string {
	return gobackend.GetSessionStatus(extensionID)
}

// GetSignedSessionAuthURL re-exportado desde internal/gobackend.
func GetSignedSessionAuthURL(extensionID string) string {
	return gobackend.GetSignedSessionAuthURL(extensionID)
}

// GetSignedSessionStatus re-exportado desde internal/gobackend.
func GetSignedSessionStatus(extensionID string) string {
	return gobackend.GetSignedSessionStatus(extensionID)
}

// KeepAliveSignedSessions re-exportado desde internal/gobackend.
func KeepAliveSignedSessions(payload string) string {
	return gobackend.KeepAliveSignedSessions(payload)
}

// ListSessions re-exportado desde internal/gobackend.
func ListSessions() string {
	return gobackend.ListSessions()
}

// PollYoutubeOauth re-exportado desde internal/gobackend.
func PollYoutubeOauth(payload string) string {
	return gobackend.PollYoutubeOauth(payload)
}

// ProvisionSignedSessions re-exportado desde internal/gobackend.
func ProvisionSignedSessions(payload string) string {
	return gobackend.ProvisionSignedSessions(payload)
}

// RefreshSessionToken re-exportado desde internal/gobackend.
func RefreshSessionToken(extensionID string) string {
	return gobackend.RefreshSessionToken(extensionID)
}

// RefreshYoutubeOauth re-exportado desde internal/gobackend.
func RefreshYoutubeOauth(payload string) string {
	return gobackend.RefreshYoutubeOauth(payload)
}

// RevokeSession re-exportado desde internal/gobackend.
func RevokeSession(extensionID string) string {
	return gobackend.RevokeSession(extensionID)
}

// SetSessionConfig re-exportado desde internal/gobackend.
func SetSessionConfig(payload string) string {
	return gobackend.SetSessionConfig(payload)
}

// SetSignedSessionCallbackURL re-exportado desde internal/gobackend.
func SetSignedSessionCallbackURL(url string) string {
	return gobackend.SetSignedSessionCallbackURL(url)
}

// StartYoutubeOauth re-exportado desde internal/gobackend.
func StartYoutubeOauth(payload string) string {
	return gobackend.StartYoutubeOauth(payload)
}

// StopYoutubeOauth re-exportado desde internal/gobackend.
func StopYoutubeOauth(payload string) string {
	return gobackend.StopYoutubeOauth(payload)
}
