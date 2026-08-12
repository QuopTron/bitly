package premium

import (
	"testing"
	"time"
)

func TestValidateCode_Empty(t *testing.T) {
	c := NewChecker(nil)
	if err := c.ValidateCode(""); err == nil {
		t.Error("expected error for empty code")
	}
}

func TestValidateCode_Whitespace(t *testing.T) {
	c := NewChecker(nil)
	if err := c.ValidateCode("   "); err == nil {
		t.Error("expected error for whitespace-only code")
	}
}

func TestValidateCode_Unknown(t *testing.T) {
	c := NewChecker(nil)
	if err := c.ValidateCode("MADEUP-123"); err == nil {
		t.Error("expected error for unknown code")
	}
}

func TestValidateCode_ValidPreLoaded(t *testing.T) {
	codes := []CodeEntry{{Code: "PREMIUM2026", Tier: "premium", ExpiresAt: 0, MaxUses: 0}}
	c := NewChecker(codes)
	if err := c.ValidateCode("PREMIUM2026"); err != nil {
		t.Fatalf("expected valid code: %v", err)
	}
	if !c.IsPremium() {
		t.Error("should be premium after valid code")
	}
}

func TestValidateCode_Expired(t *testing.T) {
	codes := []CodeEntry{{
		Code: "EXPIRED", Tier: "premium",
		ExpiresAt: time.Now().Add(-1 * time.Hour).Unix(),
		MaxUses:   0,
	}}
	c := NewChecker(codes)
	if err := c.ValidateCode("EXPIRED"); err == nil {
		t.Error("expected error for expired code")
	}
	if c.IsPremium() {
		t.Error("should not be premium after expired code")
	}
}

func TestValidateCode_MaxUsesExhausted(t *testing.T) {
	codes := []CodeEntry{{Code: "LIMITED", Tier: "premium", ExpiresAt: 0, MaxUses: 1, UsedCount: 1}}
	c := NewChecker(codes)
	if err := c.ValidateCode("LIMITED"); err == nil {
		t.Error("expected error for exhausted code")
	}
}

func TestValidateCode_TracksUsageCount(t *testing.T) {
	codes := []CodeEntry{{Code: "TWOTIMES", Tier: "premium", ExpiresAt: 0, MaxUses: 2}}
	c := NewChecker(codes)
	if err := c.ValidateCode("TWOTIMES"); err != nil {
		t.Fatalf("first use should work: %v", err)
	}
	c.SetPremium(false, "")
	if err := c.ValidateCode("TWOTIMES"); err != nil {
		t.Fatalf("second use should work: %v", err)
	}
	c.SetPremium(false, "")
	if err := c.ValidateCode("TWOTIMES"); err == nil {
		t.Error("third use should fail (max 2)")
	}
}

func TestValidateCode_DifferentTiers(t *testing.T) {
	codes := []CodeEntry{
		{Code: "LIFETIME", Tier: "lifetime", ExpiresAt: 0, MaxUses: 0},
		{Code: "MONTHLY", Tier: "premium", ExpiresAt: time.Now().Add(30 * 24 * time.Hour).Unix(), MaxUses: 0},
	}
	c := NewChecker(codes)

	if err := c.ValidateCode("LIFETIME"); err != nil {
		t.Fatalf("lifetime code: %v", err)
	}
	s := c.Status()
	if s.Tier != "lifetime" {
		t.Errorf("expected tier 'lifetime', got %q", s.Tier)
	}

	c.SetPremium(false, "")
	if err := c.ValidateCode("MONTHLY"); err != nil {
		t.Fatalf("monthly code: %v", err)
	}
	s = c.Status()
	if s.Tier != "premium" {
		t.Errorf("expected tier 'premium', got %q", s.Tier)
	}
}

func TestValidateCode_HMACValid(t *testing.T) {
	c := NewChecker(nil)
	code := GenerateCode("FRIENDS2026")
	if err := c.ValidateCode(code); err != nil {
		t.Fatalf("expected valid HMAC code %q: %v", code, err)
	}
	if !c.IsPremium() {
		t.Error("should be premium after HMAC code")
	}
	s := c.Status()
	if s.Tier != "premium" {
		t.Errorf("expected tier 'premium' for HMAC code, got %q", s.Tier)
	}
	if s.ExpiresAt == 0 {
		t.Error("HMAC code should set an expiration (1 year)")
	}
}

func TestValidateCode_HMACInvalidSignature(t *testing.T) {
	c := NewChecker(nil)
	err := c.ValidateCode("BITLY-FRIENDS2026-INVALID")
	if err == nil {
		t.Error("expected error for invalid HMAC signature")
	}
}

func TestValidateCode_HMACWrongFormat(t *testing.T) {
	c := NewChecker(nil)
	err := c.ValidateCode("BITLY-ONLYONEPART")
	if err == nil {
		t.Error("expected error for wrong HMAC format")
	}
}
