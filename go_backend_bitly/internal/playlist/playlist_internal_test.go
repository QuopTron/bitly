package playlist

import (
	"strings"
	"testing"
)

func TestFormatDuration(t *testing.T) {
	tests := []struct {
		in  int
		out string
	}{
		{0, "0:00"},
		{-5, "0:00"},
		{59, "0:59"},
		{60, "1:00"},
		{3661, "61:01"},
	}
	for _, tt := range tests {
		got := formatDuration(tt.in)
		if got != tt.out {
			t.Errorf("formatDuration(%d) = %q, want %q", tt.in, got, tt.out)
		}
	}
}

func TestSanitize(t *testing.T) {
	got := sanitize(`a<b>c\d|e?f*g:g"`)
	if strings.ContainsAny(got, `<>:"/\|?*`) {
		t.Errorf("sanitized %q still contains invalid chars", got)
	}
}

func TestGenerateM3U_EmptyTracks(t *testing.T) {
	_, err := GenerateM3U(Config{Name: "test"})
	if err == nil || !strings.Contains(err.Error(), "no tracks") {
		t.Fatalf("expected 'no tracks' error, got %v", err)
	}
}

func TestGenerateM3U8_EmptyTracks(t *testing.T) {
	_, err := GenerateM3U8(Config{Name: "test"})
	if err == nil || !strings.Contains(err.Error(), "no tracks") {
		t.Fatalf("expected 'no tracks' error, got %v", err)
	}
}

func TestGenerateCUE_EmptyTracks(t *testing.T) {
	_, err := GenerateCUE(Config{Name: "test"})
	if err == nil || !strings.Contains(err.Error(), "no tracks") {
		t.Fatalf("expected 'no tracks' error, got %v", err)
	}
}
