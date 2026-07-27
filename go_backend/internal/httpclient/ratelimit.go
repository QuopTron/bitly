package httpclient

import (
	"sync"
	"time"
)

// rateLimiter controls request frequency for a single domain.
type rateLimiter struct {
	tokens     int
	maxTokens  int
	refillRate float64 // tokens per second
	lastRefill time.Time
	mu         sync.Mutex
}

// RateLimitConfig defines per-domain rate limits.
type RateLimitConfig struct {
	RequestsPerSecond float64
	Burst             int
}

// RateLimiter manages multiple per-domain rate limiters.
type RateLimiter struct {
	mu     sync.Mutex
	limits map[string]*rateLimiter
	def    RateLimitConfig
}

// NewRateLimiter creates a global rate limiter with the given default config.
func NewRateLimiter(cfg RateLimitConfig) *RateLimiter {
	if cfg.Burst < 1 {
		cfg.Burst = 1
	}
	if cfg.RequestsPerSecond <= 0 {
		cfg.RequestsPerSecond = 10
	}
	return &RateLimiter{
		limits: make(map[string]*rateLimiter),
		def:    cfg,
	}
}

// Wait blocks until a request is allowed for the given domain.
func (rl *RateLimiter) Wait(domain string) {
	rl.mu.Lock()
	lim, ok := rl.limits[domain]
	if !ok {
		lim = &rateLimiter{
			tokens:     rl.def.Burst,
			maxTokens:  rl.def.Burst,
			refillRate: rl.def.RequestsPerSecond,
			lastRefill: time.Now(),
		}
		rl.limits[domain] = lim
	}
	rl.mu.Unlock()

	lim.mu.Lock()
	defer lim.mu.Unlock()

	now := time.Now()
	elapsed := now.Sub(lim.lastRefill).Seconds()
	lim.tokens = min(lim.maxTokens, lim.tokens+int(elapsed*lim.refillRate))
	lim.lastRefill = now

	if lim.tokens <= 0 {
		waitDuration := time.Duration(float64(time.Second) / lim.refillRate)
		time.Sleep(waitDuration)
		lim.tokens = 0
	}
	lim.tokens--
}
