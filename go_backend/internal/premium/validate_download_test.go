package premium

import (
	"testing"
	"time"
)

func TestCheckDownloadAllowed_Free(t *testing.T) {
	c := NewChecker(nil)
	if err := c.CheckDownloadAllowed(); err == nil {
		t.Error("expected error for free user")
	}
}

func TestCheckDownloadAllowed_Premium(t *testing.T) {
	codes := []CodeEntry{{Code: "DOWNLOADER", Tier: "premium", ExpiresAt: 0, MaxUses: 0}}
	c := NewChecker(codes)
	_ = c.ValidateCode("DOWNLOADER")
	if err := c.CheckDownloadAllowed(); err != nil {
		t.Errorf("expected nil for premium user: %v", err)
	}
}

func TestCheckDownloadAllowed_Expired(t *testing.T) {
	codes := []CodeEntry{{
		Code: "EXPIREDDL", Tier: "premium",
		ExpiresAt: time.Now().Add(-1 * time.Hour).Unix(), MaxUses: 0,
	}}
	c := NewChecker(codes)
	_ = c.ValidateCode("EXPIREDDL")
	if err := c.CheckDownloadAllowed(); err == nil {
		t.Error("expected error for expired premium")
	}
}

func TestCheckDownloadAllowed_Lifetime(t *testing.T) {
	c := NewChecker(nil)
	c.SetPremium(true, "lifetime")
	if err := c.CheckDownloadAllowed(); err != nil {
		t.Errorf("expected nil for lifetime: %v", err)
	}
}
