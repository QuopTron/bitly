package gobackend

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend/internal/extensions"
)

// =========================================================================
// EXTENSIONS — Signed Session v2 (ZARZ-HMAC-V1 / Cloudflare challenge)
// These exports bridge to the sandbox runtime where sessions actually live.
// Flutter drives: get auth URL -> open WebView -> capture grant -> exchange.
// =========================================================================

// GetSignedSessionAuthURL triggers bootstrap for a bundled extension and
// returns the Cloudflare challenge URL (or empty if a session was
// provisioned silently).
func GetSignedSessionAuthURL(extensionID string) string {
	sb := signedSessionSandbox(extensionID)
	if sb == nil {
		return jsonErrorStr("extensión no cargada: " + extensionID)
	}
	authURL, err := sb.SignedSessionAuthURL()
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(map[string]any{"auth_url": authURL, "needsVerification": authURL != ""})
	return string(data)
}

// GetPendingVerificationUrl returns the pending Cloudflare challenge URL for an
// extension (empty string if no verification is needed).
// Flutter contract: {extension_id} → {auth_url, needsVerification}.
func GetPendingVerificationUrl(payload string) string {
	var params struct {
		ExtensionID string `json:"extension_id"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"auth_url":"","needsVerification":false}`
	}
	return GetSignedSessionAuthURL(params.ExtensionID)
}

// TriggerExtensionVerification proactively triggers bootstrap + challenge for an
// extension. Same contract as GetPendingVerificationUrl.
func TriggerExtensionVerification(payload string) string {
	var params struct {
		ExtensionID string `json:"extension_id"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"auth_url":"","needsVerification":false}`
	}
	return GetSignedSessionAuthURL(params.ExtensionID)
}

// CompleteSignedSessionGrant exchanges a grant code captured from the
// Cloudflare challenge callback (spotiflac://session-grant?code=...).
// Flutter contract: {extension_id, grant_code} → {success: bool}.
func CompleteSignedSessionGrant(payload string) string {
	var params struct {
		ExtensionID string `json:"extension_id"`
		GrantCode   string `json:"grant_code"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	sb := signedSessionSandbox(params.ExtensionID)
	if sb == nil {
		return `{"success":false,"error":"extensión no cargada"}`
	}
	if err := sb.SignedSessionCompleteGrant(params.GrantCode); err != nil {
		return `{"success":false,"error":"` + err.Error() + `"}`
	}
	return `{"success":true}`
}

// GetSignedSessionStatus returns the v2 signed-session status for an
// extension, including install_id so Flutter can display auth state.
func GetSignedSessionStatus(extensionID string) string {
	sb := signedSessionSandbox(extensionID)
	if sb == nil {
		return `{"authenticated":false,"error":"extensión no cargada"}`
	}
	data, _ := json.Marshal(sb.SignedSessionStatus())
	return string(data)
}

// SetSignedSessionCallbackURL re-points the Cloudflare challenge callback to a
// custom URL (desktop: loopback HTTP server so the grant returns without a
// custom URI scheme). Mobile leaves it empty to use the manifest's
// spotiflac:// deep link.
func SetSignedSessionCallbackURL(url string) string {
	extensions.SetSignedSessionCallbackURL(url)
	return `{"ok":true}`
}

// ClearSignedSession wipes the in-memory signed session for an extension.
func ClearSignedSession(extensionID string) string {
	sb := signedSessionSandbox(extensionID)
	if sb == nil {
		return `{"error":"extensión no cargada"}`
	}
	sb.SignedSessionClear()
	return `{"ok":true}`
}

// signedSessionSandbox resolves the extension's sandbox by ID.
func signedSessionSandbox(extensionID string) *extensions.Sandbox {
	if extRegistry == nil {
		return nil
	}
	return extRegistry.Runtime().Sandbox(extensionID)
}
