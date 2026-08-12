package premium

import (
	"testing"
	"time"
)

func TestNewChecker_StartsFree(t *testing.T) {
	c := NewChecker(nil)
	if c.IsPremium() {
		t.Error("new checker should not be premium")
	}
	s := c.Status()
	if s.Tier != "free" {
		t.Errorf("expected tier 'free', got %q", s.Tier)
	}
	if s.IsPremium {
		t.Error("status.IsPremium should be false")
	}
}

func TestNewChecker_WithInitialCodes(t *testing.T) {
	codes := []CodeEntry{
		{Code: "ALPHA", Tier: "premium", ExpiresAt: 0, MaxUses: 0},
	}
	c := NewChecker(codes)
	if err := c.ValidateCode("ALPHA"); err != nil {
		t.Errorf("expected ALPHA to be valid: %v", err)
	}
}

func TestNewChecker_NilCodes(t *testing.T) {
	c := NewChecker(nil)
	_ = c.IsPremium()
	_ = c.Status()
}

func TestSetPremium_Activate(t *testing.T) {
	c := NewChecker(nil)
	c.SetPremium(true, "premium")
	if !c.IsPremium() {
		t.Error("should be premium after SetPremium(true)")
	}
	s := c.Status()
	if s.Tier != "premium" {
		t.Errorf("expected tier 'premium', got %q", s.Tier)
	}
}

func TestSetPremium_Deactivate(t *testing.T) {
	c := NewChecker(nil)
	c.SetPremium(true, "premium")
	c.SetPremium(false, "")
	if c.IsPremium() {
		t.Error("should not be premium after SetPremium(false)")
	}
	s := c.Status()
	if s.Tier != "free" {
		t.Errorf("expected tier 'free' after deactivation, got %q", s.Tier)
	}
	if s.Code != "" {
		t.Errorf("expected empty code after deactivation, got %q", s.Code)
	}
}

func TestSetPremium_LifetimeTier(t *testing.T) {
	c := NewChecker(nil)
	c.SetPremium(true, "lifetime")
	s := c.Status()
	if s.Tier != "lifetime" {
		t.Errorf("expected tier 'lifetime', got %q", s.Tier)
	}
}

func TestStatus_MasksCode(t *testing.T) {
	codes := []CodeEntry{
		{Code: "TESTCODE123", Tier: "premium", ExpiresAt: time.Now().Add(1 * time.Hour).Unix()},
	}
	c := NewChecker(codes)
	_ = c.ValidateCode("TESTCODE123")
	s := c.Status()
	if s.Code != "TEST*******" {
		t.Errorf("expected masked code 'TEST*******', got %q", s.Code)
	}
}

func TestStatus_ShortCodeMask(t *testing.T) {
	codes := []CodeEntry{{Code: "AB", Tier: "premium"}}
	c := NewChecker(codes)
	_ = c.ValidateCode("AB")
	s := c.Status()
	if s.Code != "AB" {
		t.Errorf("short code should not be masked, got %q", s.Code)
	}
}
