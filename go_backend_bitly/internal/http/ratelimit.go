package httpclient

import (
	"sync"
	"time"
)

// RateLimiter enforces a maximum number of requests within a sliding time window.
type RateLimiter struct {
	mu          sync.Mutex
	maxRequests int
	window      time.Duration
	timestamps  []time.Time
}

// NewRateLimiter creates a rate limiter.
func NewRateLimiter(maxRequests int, window time.Duration) *RateLimiter {
	return &RateLimiter{
		maxRequests: maxRequests,
		window:      window,
		timestamps:  make([]time.Time, 0, maxRequests),
	}
}

// WaitForSlot blocks until a slot is available, respecting the rate limit.
func (r *RateLimiter) WaitForSlot() {
	r.mu.Lock()
	now := time.Now()
	r.cleanOldTimestamps(now)

	if len(r.timestamps) < r.maxRequests {
		r.timestamps = append(r.timestamps, now)
		r.mu.Unlock()
		return
	}

	oldestTimestamp := r.timestamps[0]
	waitUntil := oldestTimestamp.Add(r.window)
	waitDuration := waitUntil.Sub(now)

	if waitDuration > 0 {
		r.mu.Unlock()
		time.Sleep(waitDuration)
		r.mu.Lock()
		r.cleanOldTimestamps(time.Now())
	}

	r.timestamps = append(r.timestamps, time.Now())
	r.mu.Unlock()
}

// TryAcquire attempts to acquire a slot without blocking. Returns false if rate-limited.
func (r *RateLimiter) TryAcquire() bool {
	r.mu.Lock()
	defer r.mu.Unlock()

	now := time.Now()
	r.cleanOldTimestamps(now)

	if len(r.timestamps) < r.maxRequests {
		r.timestamps = append(r.timestamps, now)
		return true
	}

	return false
}

// Available returns the number of available slots in the current window.
func (r *RateLimiter) Available() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.cleanOldTimestamps(time.Now())
	return r.maxRequests - len(r.timestamps)
}

func (r *RateLimiter) cleanOldTimestamps(now time.Time) {
	cutoff := now.Add(-r.window)
	validStart := 0
	for i, ts := range r.timestamps {
		if ts.After(cutoff) {
			validStart = i
			break
		}
		validStart = i + 1
	}
	if validStart > 0 {
		r.timestamps = r.timestamps[validStart:]
	}
}

// Global SongLink rate limiter: 9 requests per minute (limit is 10).
var SongLinkRateLimiter = NewRateLimiter(9, time.Minute)
