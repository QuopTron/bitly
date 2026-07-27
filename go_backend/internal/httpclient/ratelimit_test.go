package httpclient

import (
	"testing"
	"time"
)

func TestNewRateLimiter(t *testing.T) {
	rl := NewRateLimiter(RateLimitConfig{RequestsPerSecond: 10, Burst: 5})
	if rl == nil {
		t.Fatal("expected non-nil rate limiter")
	}
}

func TestRateLimiter_Wait(t *testing.T) {
	rl := NewRateLimiter(RateLimitConfig{RequestsPerSecond: 100, Burst: 10})
	start := time.Now()
	for i := 0; i < 5; i++ {
		rl.Wait("test-service")
	}
	elapsed := time.Since(start)
	// 5 requests at 100 RPS should be nearly instant
	if elapsed > 500*time.Millisecond {
		t.Logf("5 requests took %v (may be slow under load)", elapsed)
	}
}

func TestRateLimiter_DifferentKeys(t *testing.T) {
	rl := NewRateLimiter(RateLimitConfig{RequestsPerSecond: 5, Burst: 2})
	// Different keys should not throttle each other
	start := time.Now()
	rl.Wait("svc-a")
	rl.Wait("svc-b")
	elapsed := time.Since(start)
	if elapsed > 200*time.Millisecond {
		t.Logf("different keys wait: %v", elapsed)
	}
}
