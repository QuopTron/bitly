package premium

import (
	"strings"
	"sync"
	"testing"
)

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

func TestSetSecretKey_ChangesValidation(t *testing.T) {
	origKey := string(secretKey)
	defer SetSecretKey(origKey)

	c := NewChecker(nil)
	code := GenerateCode("OLDSECRET")
	if err := c.ValidateCode(code); err != nil {
		t.Fatalf("code should be valid with original key: %v", err)
	}

	SetSecretKey("completely-different-key")
	code2 := GenerateCode("OLDSECRET")

	c.SetPremium(false, "")
	if err := c.ValidateCode(code); err == nil {
		t.Error("old code should be invalid after key change")
	}
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

func TestValidateCode_HMACAfterKeyChange(t *testing.T) {
	origKey := string(secretKey)
	defer SetSecretKey(origKey)

	c := NewChecker(nil)
	code := GenerateCode("PROMO")
	SetSecretKey("new-secret-key-2026")
	if err := c.ValidateCode(code); err == nil {
		t.Error("expected code to be invalid after key change")
	}
}

func TestConcurrentAccess(t *testing.T) {
	c := NewChecker(nil)
	var wg sync.WaitGroup
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
}

func TestValidateCode_TrimsWhitespace(t *testing.T) {
	codes := []CodeEntry{{Code: "TRIM", Tier: "premium", ExpiresAt: 0, MaxUses: 0}}
	c := NewChecker(codes)
	if err := c.ValidateCode("  TRIM  "); err != nil {
		t.Errorf("expected code with surrounding spaces to work: %v", err)
	}
}

func TestStatus_Immutable(t *testing.T) {
	c := NewChecker(nil)
	s := c.Status()
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
