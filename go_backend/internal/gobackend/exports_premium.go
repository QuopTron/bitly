package gobackend

import (
	"encoding/json"
)

// =========================================================================
// PREMIUM — License validation, download blocking for free users
// =========================================================================

// ValidatePremiumCode valida un código premium en el formato legacy de la app
// (JWT dataB64.sigB64, ver internal/premium/validador_app.go). El payload es
// {"code": "..."} — el flujo completo (estructura + registro GitHub + marcar
// usado) corre en Go y activa premium local si el código es válido.
func ValidatePremiumCode(payload string) string {
	var params struct {
		Code string `json:"code"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return jsonError(err)
	}
	if premiumChecker == nil {
		return `{"error":"no inicializado"}`
	}
	if err := premiumChecker.ValidateAppCode(params.Code); err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(premiumChecker.Status())
	return string(data)
}

// SetPremiumGithubToken guarda el token personal de GitHub que usa la
// validación premium para consultar el registro de códigos. Payload:
// {"token": "..."}. Lo manda Flutter al iniciar el backend.
func SetPremiumGithubToken(payload string) string {
	var params struct {
		Token string `json:"token"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	if premiumChecker == nil {
		return `{"error":"no inicializado"}`
	}
	premiumChecker.SetGithubToken(params.Token)
	return `{"ok":true}`
}

// SetPremiumStatus syncs the premium state from Flutter storage (drift) into
// Go — lo manda el app al arrancar para que el gate de descargas respete
// códigos ya activados. Payload: {"isPremium": bool, "tier": "...",
// "expiresAt": epochSeconds}. expiresAt 0 = nunca expira.
func SetPremiumStatus(payload string) string {
	if premiumChecker == nil {
		return `{"error":"no inicializado"}`
	}
	var params struct {
		IsPremium bool   `json:"isPremium"`
		Tier      string `json:"tier"`
		ExpiresAt int64  `json:"expiresAt"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	premiumChecker.SetPremiumConExpiracion(params.IsPremium, params.Tier, params.ExpiresAt)
	return `{"ok":true}`
}

// GetPremiumStatus returns the current premium state.
func GetPremiumStatus() string {
	if premiumChecker == nil {
		return `{"isPremium":false,"tier":"free"}`
	}
	data, _ := json.Marshal(premiumChecker.Status())
	return string(data)
}

// CheckDownloadAllowed returns ok if downloads are allowed, error if blocked.
func CheckDownloadAllowed() string {
	if premiumChecker == nil {
		return `{"error":"no inicializado"}`
	}
	if err := premiumChecker.CheckDownloadAllowed(); err != nil {
		return jsonError(err)
	}
	return `{"ok":true}`
}
