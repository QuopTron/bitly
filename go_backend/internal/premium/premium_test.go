package premium

import (
	"strings"
	"sync"
	"testing"
	"time"
)

// ─── NewChecker ───────────────────────────────────────────────

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
	// Should not panic
	_ = c.IsPremium()
	_ = c.Status()
}

// ─── SetPremium / IsPremium ───────────────────────────────────

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

// ─── Status ───────────────────────────────────────────────────

func TestStatus_MasksCode(t *testing.T) {
	c := NewChecker(nil)
	// Activate via valid pre-loaded code for clean state
	codes := []CodeEntry{
		{Code: "TESTCODE123", Tier: "premium", ExpiresAt: time.Now().Add(1 * time.Hour).Unix()},
	}
	c = NewChecker(codes)
	_ = c.ValidateCode("TESTCODE123")

	s := c.Status()
	// Code should be masked: first 4 chars + rest = *
	// "TESTCODE123" has 11 chars → "TEST" + 7 asterisks
	if s.Code != "TEST*******" {
		t.Errorf("expected masked code 'TEST*******', got %q", s.Code)
	}
}

func TestStatus_ShortCodeMask(t *testing.T) {
	c := NewChecker(nil)
	codes := []CodeEntry{
		{Code: "AB", Tier: "premium"},
	}
	c = NewChecker(codes)
	_ = c.ValidateCode("AB")

	s := c.Status()
	if s.Code != "AB" {
		t.Errorf("short code should not be masked, got %q", s.Code)
	}
}

// ─── ValidateCode: pre-loaded codes ──────────────────────────

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
	codes := []CodeEntry{
		{Code: "PREMIUM2026", Tier: "premium", ExpiresAt: 0, MaxUses: 0},
	}
	c := NewChecker(codes)
	if err := c.ValidateCode("PREMIUM2026"); err != nil {
		t.Fatalf("expected valid code: %v", err)
	}
	if !c.IsPremium() {
		t.Error("should be premium after valid code")
	}
}

func TestValidateCode_Expired(t *testing.T) {
	codes := []CodeEntry{
		{
			Code:      "EXPIRED",
			Tier:      "premium",
			ExpiresAt: time.Now().Add(-1 * time.Hour).Unix(), // 1 hour ago
			MaxUses:   0,
		},
	}
	c := NewChecker(codes)
	if err := c.ValidateCode("EXPIRED"); err == nil {
		t.Error("expected error for expired code")
	}
	if c.IsPremium() {
		t.Error("should not be premium after expired code")
	}
}

func TestValidateCode_MaxUsesExhausted(t *testing.T) {
	codes := []CodeEntry{
		{Code: "LIMITED", Tier: "premium", ExpiresAt: 0, MaxUses: 1, UsedCount: 1},
	}
	c := NewChecker(codes)
	if err := c.ValidateCode("LIMITED"); err == nil {
		t.Error("expected error for exhausted code")
	}
}

func TestValidateCode_TracksUsageCount(t *testing.T) {
	codes := []CodeEntry{
		{Code: "TWOTIMES", Tier: "premium", ExpiresAt: 0, MaxUses: 2},
	}
	c := NewChecker(codes)

	// First use
	if err := c.ValidateCode("TWOTIMES"); err != nil {
		t.Fatalf("first use should work: %v", err)
	}

	// Deactivate and re-activate for second use
	c.SetPremium(false, "")
	if err := c.ValidateCode("TWOTIMES"); err != nil {
		t.Fatalf("second use should work: %v", err)
	}

	// Third use should fail
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

	// Lifetime
	if err := c.ValidateCode("LIFETIME"); err != nil {
		t.Fatalf("lifetime code: %v", err)
	}
	s := c.Status()
	if s.Tier != "lifetime" {
		t.Errorf("expected tier 'lifetime', got %q", s.Tier)
	}

	// Monthly
	c.SetPremium(false, "")
	if err := c.ValidateCode("MONTHLY"); err != nil {
		t.Fatalf("monthly code: %v", err)
	}
	s = c.Status()
	if s.Tier != "premium" {
		t.Errorf("expected tier 'premium', got %q", s.Tier)
	}
}

// ─── ValidateCode: HMAC-generated codes ──────────────────────

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
	// BITLY- prefix with wrong signature
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

func TestValidateCode_HMACAfterKeyChange(t *testing.T) {
	// Save and restore original key
	origKey := string(secretKey)
	defer SetSecretKey(origKey)

	c := NewChecker(nil)
	code := GenerateCode("PROMO")

	// Change key
	SetSecretKey("new-secret-key-2026")

	// Old code should now be invalid
	if err := c.ValidateCode(code); err == nil {
		t.Error("expected code to be invalid after key change")
	}
}

// ─── CheckDownloadAllowed ─────────────────────────────────────

func TestCheckDownloadAllowed_Free(t *testing.T) {
	c := NewChecker(nil)
	if err := c.CheckDownloadAllowed(); err == nil {
		t.Error("expected error for free user")
	}
}

func TestCheckDownloadAllowed_Premium(t *testing.T) {
	codes := []CodeEntry{
		{Code: "DOWNLOADER", Tier: "premium", ExpiresAt: 0, MaxUses: 0},
	}
	c := NewChecker(codes)
	_ = c.ValidateCode("DOWNLOADER")

	if err := c.CheckDownloadAllowed(); err != nil {
		t.Errorf("expected nil for premium user: %v", err)
	}
}

func TestCheckDownloadAllowed_Expired(t *testing.T) {
	codes := []CodeEntry{
		{
			Code:      "EXPIREDDL",
			Tier:      "premium",
			ExpiresAt: time.Now().Add(-1 * time.Hour).Unix(),
			MaxUses:   0,
		},
	}
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

// ─── GenerateCode ─────────────────────────────────────────────

func TestGenerateCode_Format(t *testing.T) {
	code := GenerateCode("TESTPAYLOAD")
	if !strings.HasPrefix(code, "BITLY-") {
		t.Errorf("expected BITLY- prefix, got %q", code)
	}
	parts := strings.Split(code, "-")
	if len(parts) != 3 {
		t.Errorf("expected 3 parts separated by '-', got %d", len(parts))
	}
	if len(parts[2]) != 6 {
		t.Errorf("expected 6-char signature, got %q (len %d)", parts[2], len(parts[2]))
	}
}

func TestGenerateCode_Deterministic(t *testing.T) {
	code1 := GenerateCode("UNIQUE")
	code2 := GenerateCode("UNIQUE")
	if code1 != code2 {
		t.Errorf("same payload should produce same code: %q vs %q", code1, code2)
	}
}

func TestGenerateCode_DifferentPayloads(t *testing.T) {
	code1 := GenerateCode("PAYLOAD1")
	code2 := GenerateCode("PAYLOAD2")
	if code1 == code2 {
		t.Error("different payloads should produce different codes")
	}
}

// ─── SetSecretKey ─────────────────────────────────────────────

func TestSetSecretKey_ChangesValidation(t *testing.T) {
	origKey := string(secretKey)
	defer SetSecretKey(origKey)

	c := NewChecker(nil)

	// Generate with original key
	code := GenerateCode("OLDSECRET")
	if err := c.ValidateCode(code); err != nil {
		t.Fatalf("code should be valid with original key: %v", err)
	}

	// Change key
	SetSecretKey("completely-different-key")

	// New code generated with new key
	code2 := GenerateCode("OLDSECRET")

	// Old code should now be invalid
	c.SetPremium(false, "")
	if err := c.ValidateCode(code); err == nil {
		t.Error("old code should be invalid after key change")
	}

	// New code should be valid
	if err := c.ValidateCode(code2); err != nil {
		t.Errorf("new code should be valid: %v", err)
	}
}

func TestSetSecretKey_EmptyDoesNothing(t *testing.T) {
	origKey := string(secretKey)
	SetSecretKey("")
	currentKey := string(secretKey)
	if currentKey != origKey {
		t.Error("SetSecretKey('') should not change the key")
	}
}

// ─── Concurrency ──────────────────────────────────────────────

func TestConcurrentAccess(t *testing.T) {
	c := NewChecker(nil)
	var wg sync.WaitGroup

	// Spawn multiple goroutines that read/write simultaneously
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func(n int) {
			defer wg.Done()
			if n%2 == 0 {
				c.IsPremium()
				c.Status()
				_ = c.CheckDownloadAllowed()
			} else {
				c.SetPremium(true, "premium")
				c.SetPremium(false, "")
			}
		}(i)
	}
	wg.Wait()
	// Should not deadlock or race
}

// ─── Edge cases ───────────────────────────────────────────────

func TestValidateCode_TrimsWhitespace(t *testing.T) {
	codes := []CodeEntry{
		{Code: "TRIM", Tier: "premium", ExpiresAt: 0, MaxUses: 0},
	}
	c := NewChecker(codes)
	// Code with spaces should not match trimmed version — ValidateCode trims input
	// but the stored code is "TRIM" without spaces
	if err := c.ValidateCode("  TRIM  "); err != nil {
		t.Errorf("expected code with surrounding spaces to work: %v", err)
	}
}

func TestStatus_Immutable(t *testing.T) {
	c := NewChecker(nil)
	s := c.Status()
	// Modifying the returned status should not affect the checker
	s.IsPremium = true
	s.Tier = "premium"
	if c.IsPremium() {
		t.Error("modifying returned Status should not affect checker")
	}
}

func TestCheckDownloadAllowed_ErrorMessageInSpanish(t *testing.T) {
	c := NewChecker(nil)
	err := c.CheckDownloadAllowed()
	if err == nil {
		t.Fatal("expected error")
	}
	msg := err.Error()
	if !strings.Contains(msg, "premium") && !strings.Contains(msg, "código") {
		t.Errorf("expected Spanish error message about premium/código, got: %q", msg)
	}
}
