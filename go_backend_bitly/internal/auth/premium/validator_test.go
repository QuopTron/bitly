package premium

import (
	"strings"
	"testing"
	"time"
)

func TestValidateCode_Valid(t *testing.T) {
	future := time.Now().Add(24 * time.Hour).Unix()
	code, err := GenerateCode("pablo", future)
	if err != nil {
		t.Fatalf("generating code: %v", err)
	}
	status, err := ValidateCode(code)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !status.IsPremium {
		t.Error("expected IsPremium = true")
	}
	if status.Error != "" {
		t.Errorf("expected empty error, got %q", status.Error)
	}
	if status.ExpiresAt != future {
		t.Errorf("expected ExpiresAt = %d, got %d", future, status.ExpiresAt)
	}
}

func TestValidateCode_ValidDifferentWord(t *testing.T) {
	future := time.Now().Add(24 * time.Hour).Unix()
	for _, word := range []string{"pabol", "flox"} {
		code, err := GenerateCode(word, future)
		if err != nil {
			t.Fatalf("generating code for %q: %v", word, err)
		}
		status, err := ValidateCode(code)
		if err != nil {
			t.Errorf("unexpected error for word %q: %v", word, err)
		}
		if !status.IsPremium {
			t.Errorf("expected IsPremium = true for word %q", word)
		}
	}
}

func TestValidateCode_Empty(t *testing.T) {
	status, err := ValidateCode("")
	if err == nil {
		t.Fatal("expected error")
	}
	if status.Error != "Código vacío" {
		t.Errorf("expected 'Código vacío', got %q", status.Error)
	}
}

func TestValidateCode_InvalidFormat(t *testing.T) {
	status, err := ValidateCode("no-dot-separator")
	if err == nil {
		t.Fatal("expected error")
	}
	if status.Error != "Formato inválido" {
		t.Errorf("expected 'Formato inválido', got %q", status.Error)
	}
}

func TestValidateCode_InvalidBase64(t *testing.T) {
	status, err := ValidateCode("!!!.!!!")
	if err == nil {
		t.Fatal("expected error")
	}
	if status.Error != "Error decodificando datos" {
		t.Errorf("expected 'Error decodificando datos', got %q", status.Error)
	}
}

func TestValidateCode_InvalidJSON(t *testing.T) {
	status, err := ValidateCode("dGhpcyBpcyBub3QganNvbg.sig")
	if err == nil {
		t.Fatal("expected error")
	}
	if status.Error != "Error parseando JSON" {
		t.Errorf("expected 'Error parseando JSON', got %q", status.Error)
	}
}

func TestValidateCode_UnauthorizedWord(t *testing.T) {
	future := time.Now().Add(24 * time.Hour).Unix()
	code, err := GenerateCode("unknownword", future)
	if err != nil {
		t.Fatalf("generating code: %v", err)
	}
	status, err := ValidateCode(code)
	if err == nil {
		t.Fatal("expected error")
	}
	if status.Error != "Palabra no autorizada" {
		t.Errorf("expected 'Palabra no autorizada', got %q", status.Error)
	}
}

func TestValidateCode_Expired(t *testing.T) {
	past := time.Now().Add(-24 * time.Hour).Unix()
	code, err := GenerateCode("pablo", past)
	if err != nil {
		t.Fatalf("generating code: %v", err)
	}
	status, err := ValidateCode(code)
	if err == nil {
		t.Fatal("expected error")
	}
	if status.Error != "Código expirado" {
		t.Errorf("expected 'Código expirado', got %q", status.Error)
	}
}

func TestValidateCode_InvalidSignature(t *testing.T) {
	future := time.Now().Add(24 * time.Hour).Unix()
	code, err := GenerateCode("pablo", future)
	if err != nil {
		t.Fatalf("generating code: %v", err)
	}
	tampered := code[:len(code)-1] + "X"
	status, err := ValidateCode(tampered)
	if err == nil {
		t.Fatal("expected error")
	}
	if status.Error != "Firma inválida" {
		t.Errorf("expected 'Firma inválida', got %q", status.Error)
	}
}

func TestValidateCode_TamperedData(t *testing.T) {
	future := time.Now().Add(24 * time.Hour).Unix()
	code, err := GenerateCode("pablo", future)
	if err != nil {
		t.Fatalf("generating code: %v", err)
	}
	idx := strings.LastIndex(code, ".")
	if idx < 0 {
		t.Fatal("invalid code format")
	}
	tampered := code[:idx-1] + "Z" + code[idx:]
	status, err := ValidateCode(tampered)
	if err == nil {
		t.Fatal("expected error for tampered data")
	}
	if status.Error != "Firma inválida" {
		t.Errorf("expected 'Firma inválida', got %q", status.Error)
	}
}

func TestGetStatus_FreeUser(t *testing.T) {
	status, err := GetStatus("user1", 100, false)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if status.IsPremium {
		t.Error("expected IsPremium = false")
	}
	if status.TotalMinutes != FreeQuotaMinutes {
		t.Errorf("expected TotalMinutes = %d, got %d", FreeQuotaMinutes, status.TotalMinutes)
	}
	expected := float64(FreeQuotaMinutes) - 100
	if status.RemainingMinutes != expected {
		t.Errorf("expected RemainingMinutes = %.0f, got %.0f", expected, status.RemainingMinutes)
	}
	if !status.CanDownload {
		t.Error("expected CanDownload = true")
	}
}

func TestGetStatus_FreeUserExhausted(t *testing.T) {
	status, err := GetStatus("user1", 800, false)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if status.RemainingMinutes != 0 {
		t.Errorf("expected RemainingMinutes = 0, got %f", status.RemainingMinutes)
	}
	if status.CanDownload {
		t.Error("expected CanDownload = false")
	}
}

func TestGetStatus_FreeUserExactLimit(t *testing.T) {
	status, err := GetStatus("user1", float64(FreeQuotaMinutes), false)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if status.RemainingMinutes != 0 {
		t.Errorf("expected RemainingMinutes = 0, got %f", status.RemainingMinutes)
	}
	if status.CanDownload {
		t.Error("expected CanDownload = false when exactly at limit")
	}
}

func TestGetStatus_FreeUserZeroUsed(t *testing.T) {
	status, err := GetStatus("user1", 0, false)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if status.RemainingMinutes != float64(FreeQuotaMinutes) {
		t.Errorf("expected RemainingMinutes = %d, got %f", FreeQuotaMinutes, status.RemainingMinutes)
	}
	if !status.CanDownload {
		t.Error("expected CanDownload = true")
	}
}

func TestGetStatus_PremiumUser(t *testing.T) {
	status, err := GetStatus("user1", 500, true)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !status.IsPremium {
		t.Error("expected IsPremium = true")
	}
	if status.TotalMinutes != PremiumQuotaMinutes {
		t.Errorf("expected TotalMinutes = %d, got %d", PremiumQuotaMinutes, status.TotalMinutes)
	}
	if status.RemainingMinutes != -1 {
		t.Errorf("expected RemainingMinutes = -1, got %f", status.RemainingMinutes)
	}
	if !status.CanDownload {
		t.Error("expected CanDownload = true")
	}
}

func TestGetStatus_PremiumUserZeroUsed(t *testing.T) {
	status, err := GetStatus("user1", 0, true)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !status.IsPremium {
		t.Error("expected IsPremium = true")
	}
	if status.RemainingMinutes != -1 {
		t.Errorf("expected RemainingMinutes = -1, got %f", status.RemainingMinutes)
	}
}

func TestVerifyPremium_NotPremiumNoExpiration(t *testing.T) {
	err := VerifyPremium(false, 0)
	if err == nil {
		t.Error("expected error for non-premium without expiration")
	}
}

func TestVerifyPremium_NotPremiumWithFutureExpiration(t *testing.T) {
	err := VerifyPremium(false, time.Now().Add(24*time.Hour).UnixMilli())
	if err != nil {
		t.Errorf("expected nil when premiumUntil is in the future, got: %v", err)
	}
}

func TestVerifyPremium_NotPremiumWithPastExpiration(t *testing.T) {
	err := VerifyPremium(false, time.Now().Add(-24*time.Hour).UnixMilli())
	if err == nil {
		t.Error("expected error when premiumUntil is in the past")
	}
}

func TestVerifyPremium_PremiumNoExpiration(t *testing.T) {
	err := VerifyPremium(true, 0)
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestVerifyPremium_PremiumValidExpiration(t *testing.T) {
	err := VerifyPremium(true, time.Now().Add(24*time.Hour).UnixMilli())
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestVerifyPremium_PremiumExpired(t *testing.T) {
	err := VerifyPremium(true, time.Now().Add(-24*time.Hour).UnixMilli())
	if err == nil {
		t.Error("expected error for expired premium")
	}
}
