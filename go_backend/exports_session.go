package gobackend

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend/internal/extensions"
)

// =========================================================================
// EXTENSIONS — Signed Sessions (Cloudflare auth)
// =========================================================================

// SetSessionConfig stores the Cloudflare signed session configuration for an extension.
func SetSessionConfig(payload string) string {
	if sessionMgr == nil {
		return `{"error":"no inicializado"}`
	}
	var params struct {
		ExtensionID string `json:"extensionID"`
		ConfigJSON  string `json:"configJSON"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	var cfg extensions.SignedSessionConfig
	if err := json.Unmarshal([]byte(params.ConfigJSON), &cfg); err != nil {
		return jsonError(err)
	}
	if sessionConfigs == nil {
		sessionConfigs = make(map[string]*extensions.SignedSessionConfig)
	}
	sessionConfigs[params.ExtensionID] = &cfg
	return `{"ok":true}`
}

// getSessionConfig returns the stored config for an extension, or nil.
func getSessionConfig(extensionID string) *extensions.SignedSessionConfig {
	if sessionConfigs == nil {
		return nil
	}
	return sessionConfigs[extensionID]
}

// GetSessionAuthURL returns a URL for Cloudflare challenge in a WebView.
func GetSessionAuthURL(extensionID string) string {
	if sessionMgr == nil {
		return `{"error":"no inicializado"}`
	}
	cfg := getSessionConfig(extensionID)
	if cfg == nil {
		return jsonErrorStr("sesión no configurada para: " + extensionID)
	}
	result, err := sessionMgr.GetAuthURL(extensionID, cfg)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(result)
	return string(data)
}

// ExchangeSessionGrant exchanges a Cloudflare grant code for a session token.
func ExchangeSessionGrant(payload string) string {
	if sessionMgr == nil {
		return `{"error":"no inicializado"}`
	}
	var params struct {
		ExtensionID string `json:"extensionID"`
		GrantCode   string `json:"grantCode"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	cfg := getSessionConfig(params.ExtensionID)
	if cfg == nil {
		return jsonErrorStr("sesión no configurada para: " + params.ExtensionID)
	}
	state, err := sessionMgr.ExchangeGrant(params.ExtensionID, cfg, params.GrantCode)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(state)
	return string(data)
}

// GetSessionStatus returns the current Cloudflare session status for an extension.
func GetSessionStatus(extensionID string) string {
	if sessionMgr == nil {
		return `{"error":"no inicializado"}`
	}
	status := sessionMgr.GetSessionStatus(extensionID)
	data, _ := json.Marshal(status)
	return string(data)
}

// ListSessions returns all active Cloudflare sessions.
func ListSessions() string {
	if sessionMgr == nil {
		return `[]`
	}
	sessions := sessionMgr.ListActiveSessions()
	data, _ := json.Marshal(sessions)
	return string(data)
}

// RevokeSession revokes a Cloudflare session for an extension.
func RevokeSession(extensionID string) string {
	if sessionMgr == nil {
		return `{"error":"no inicializado"}`
	}
	sessionMgr.RevokeSession(extensionID)
	return `{"ok":true}`
}

// RefreshSessionToken manually refreshes a Cloudflare session token.
func RefreshSessionToken(extensionID string) string {
	if sessionMgr == nil {
		return `{"error":"no inicializado"}`
	}
	cfg := getSessionConfig(extensionID)
	if cfg == nil {
		return jsonErrorStr("sesión no configurada para: " + extensionID)
	}
	state, err := sessionMgr.RefreshSession(extensionID, cfg)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(state)
	return string(data)
}

// StoreSessionToken manually restores a session token (from Flutter storage).
func StoreSessionToken(payload string) string {
	if sessionMgr == nil {
		return `{"error":"no inicializado"}`
	}
	var params struct {
		ExtensionID  string `json:"extensionID"`
		Token        string `json:"token"`
		RefreshToken string `json:"refreshToken"`
		ExpiresIn    int    `json:"expiresIn"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	sessionMgr.StoreSessionToken(params.ExtensionID, params.Token, params.RefreshToken, params.ExpiresIn)
	return `{"ok":true}`
}
