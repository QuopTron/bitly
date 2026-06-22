package premium

import (
	"strings"
	"testing"
)

func TestGenerateCode_Valid(t *testing.T) {
	code, err := GenerateCode("pablo", 9999999999)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	parts := strings.Split(code, ".")
	if len(parts) != 2 {
		t.Fatalf("expected format data.sig, got %q", code)
	}
	if parts[0] == "" {
		t.Error("expected non-empty data part")
	}
	if parts[1] == "" {
		t.Error("expected non-empty signature part")
	}
}

func TestGenerateCode_Deterministic(t *testing.T) {
	c1, _ := GenerateCode("pablo", 9999999999)
	c2, _ := GenerateCode("pablo", 9999999999)
	if c1 != c2 {
		t.Error("expected identical codes for identical inputs (deterministic)")
	}
}

func TestGenerateCode_DifferentWords(t *testing.T) {
	c1, _ := GenerateCode("pablo", 9999999999)
	c2, _ := GenerateCode("flox", 9999999999)
	if c1 == c2 {
		t.Error("expected different codes for different words")
	}
}

func TestGenerateCode_EmptyWord(t *testing.T) {
	_, err := GenerateCode("", 12345)
	if err == nil {
		t.Fatal("expected error for empty word")
	}
}

func TestGenerateCode_WhitespaceWord(t *testing.T) {
	_, err := GenerateCode("  ", 12345)
	if err == nil {
		t.Fatal("expected error for whitespace-only word")
	}
}

func TestGenerateCode_TrailingWhitespace(t *testing.T) {
	code, err := GenerateCode("  pablo  ", 9999999999)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	parts := strings.Split(code, ".")
	if len(parts) != 2 {
		t.Fatalf("expected format data.sig, got %q", code)
	}
}

func TestParseCode_Valid(t *testing.T) {
	code, err := GenerateCode("pablo", 9999999999)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	pc, err := ParseCode(code)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if pc.Signature == "" {
		t.Error("expected non-empty signature")
	}
}

func TestParseCode_InvalidFormat_NoDot(t *testing.T) {
	_, err := ParseCode("no-dot-separator")
	if err == nil {
		t.Fatal("expected error for invalid format")
	}
}

func TestParseCode_InvalidFormat_TooManyParts(t *testing.T) {
	_, err := ParseCode("a.b.c")
	if err == nil {
		t.Fatal("expected error for too many parts")
	}
}

func TestParseCode_EmptyString(t *testing.T) {
	_, err := ParseCode("")
	if err == nil {
		t.Fatal("expected error for empty string")
	}
}

func TestParseCode_Whitespace(t *testing.T) {
	_, err := ParseCode("  ")
	if err == nil {
		t.Fatal("expected error for whitespace-only string")
	}
}

func TestParseCode_EmptyParts(t *testing.T) {
	_, err := ParseCode(".abc")
	if err != nil {
		t.Fatal("expected parse to succeed with empty data part")
	}
}
