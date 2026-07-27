package httpclient

import (
	"testing"
	"time"
)

func TestRetryConfig_Defaults(t *testing.T) {
	cfg := DefaultRetryConfig()
	if cfg.MaxRetries != 3 {
		t.Errorf("expected 3 retries, got %d", cfg.MaxRetries)
	}
	if cfg.BaseDelay != 1*time.Second {
		t.Errorf("expected 1s base delay, got %v", cfg.BaseDelay)
	}
	if cfg.MaxDelay != 30*time.Second {
		t.Errorf("expected 30s max delay, got %v", cfg.MaxDelay)
	}
	if !cfg.RetryOnEOF {
		t.Error("expected RetryOnEOF=true")
	}
}

func TestIsRetryable(t *testing.T) {
	tests := []struct {
		status int
		want   bool
	}{
		{429, true},
		{502, true},
		{503, true},
		{504, true},
		{200, false},
		{301, false},
		{404, false},
		{401, false},
		{500, false}, // 500 is not retryable by default
	}
	for _, tt := range tests {
		if got := isRetryable(tt.status); got != tt.want {
			t.Errorf("isRetryable(%d): expected %v, got %v", tt.status, tt.want, got)
		}
	}
}

func TestBackoff_Increasing(t *testing.T) {
	prev := time.Duration(0)
	for i := 0; i < 5; i++ {
		d := backoff(i, 1*time.Second, 60*time.Second)
		if d < prev {
			t.Errorf("backoff should increase, attempt %d: %v < %v", i, d, prev)
		}
		prev = d
	}
}

func TestBackoff_MaxDelay(t *testing.T) {
	for i := 0; i < 10; i++ {
		d := backoff(i, 1*time.Second, 5*time.Second)
		if d > 6*time.Second { // allow some jitter above max
			t.Errorf("backoff should cap near max, got %v", d)
		}
	}
}

func TestDoWithRetry_ConfigDefaults(t *testing.T) {
	cfg := DefaultRetryConfig()
	if cfg.MaxRetries != 3 {
		t.Errorf("expected 3 retries, got %d", cfg.MaxRetries)
	}
}
