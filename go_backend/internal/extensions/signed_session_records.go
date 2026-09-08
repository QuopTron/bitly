package extensions

import (
	"strings"
	"time"
)

type signedSessionRecord struct {
	InstallID     string `json:"install_id"`
	SessionID     string `json:"session_id,omitempty"`
	SessionSecret string `json:"session_secret,omitempty"`
	ExpiresAt     string `json:"expires_at,omitempty"`
	Namespace     string `json:"namespace,omitempty"`
	BaseURL       string `json:"base_url,omitempty"`
	AppVersion    string `json:"app_version,omitempty"`
	Platform      string `json:"platform,omitempty"`
}

type signedSessionExchangeResponse struct {
	SessionID     string `json:"session_id,omitempty"`
	SessionSecret string `json:"session_secret,omitempty"`
	ExpiresAt     string `json:"expires_at,omitempty"`
	ChallengeID   string `json:"challenge_id,omitempty"`
	ChallengeURL  string `json:"challenge_url,omitempty"`
	AuthURL       string `json:"auth_url,omitempty"`
	ServerNonce   string `json:"server_nonce,omitempty"`
}

type signedSessionErrorContract struct {
	Error             string `json:"error,omitempty"`
	Code              string `json:"code,omitempty"`
	Origin            string `json:"origin,omitempty"`
	Action            string `json:"action,omitempty"`
	Retryable         bool   `json:"retryable,omitempty"`
	RetryMode         string `json:"retry_mode,omitempty"`
	RetryAfterSeconds int    `json:"retry_after_seconds,omitempty"`
}

func registroSesionFirmadaUsable(record *signedSessionRecord) bool {
	if record == nil || strings.TrimSpace(record.SessionID) == "" ||
		strings.TrimSpace(record.SessionSecret) == "" {
		return false
	}
	if expiresAt, ok := parsearTiempoSesionFirmada(record.ExpiresAt); ok {
		return time.Now().Before(expiresAt)
	}
	return true
}
