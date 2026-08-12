package gobackend

import (
	"encoding/json"
)

// =========================================================================
// PREMIUM — License validation, download blocking for free users
// =========================================================================

// ValidatePremiumCode validates a code and activates premium if valid.
func ValidatePremiumCode(code string) string {
	if premiumChecker == nil {
		return `{"error":"no inicializado"}`
	}
	if err := premiumChecker.ValidateCode(code); err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(premiumChecker.Status())
	return string(data)
}

// SetPremiumStatus manually sets premium status (restore from Flutter storage).
func SetPremiumStatus(payload string) string {
	if premiumChecker == nil {
		return `{"error":"no inicializado"}`
	}
	var params struct {
		IsPremium bool   `json:"isPremium"`
		Tier      string `json:"tier"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	premiumChecker.SetPremium(params.IsPremium, params.Tier)
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
