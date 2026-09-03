// Package cooldown implements a lightweight per-provider circuit breaker.
//
// Providers that get rate-limited (HTTP 429), are temporarily unavailable, or
// only hand back non-streamable encrypted results are "cooled down" for a
// window so the search / fallback / prefetch loops don't hammer their API on
// every track. Cooled providers are skipped fast, and every new error that
// still matches the markers extends the window with a bounded exponential
// backoff; a successful response clears it immediately.
//
// Cooldown state is bucketed per provider, and optionally per operation class:
// op-scoped buckets (e.g. "feed", "detail") are isolated, so a rate-limit on
// one surface (a home-feed endpoint 429ing) cools only that surface and does
// not disable the provider for playback/search/download — and vice versa.
package cooldown

import (
	"math/rand"
	"strings"
	"sync"
	"time"
)

const (
	// cooldownDur is the initial window after a single rate-limit event. Kept
	// reasonably short so a provider that recovered (verification completed,
	// burst over) is retried soon, but long enough that the per-track prefetch
	// storms (each track can hit every provider) don't hammer the same API on
	// every single track.
	cooldownDur = 90 * time.Second
	// maxCooldownDur caps the exponential backoff between repeated events.
	maxCooldownDur = 8 * time.Minute
)

var (
	mu     sync.Mutex
	cooled = map[string]time.Time{}
)

// opKey maps a provider + operation class to its cooldown bucket. The empty
// class "" maps to the provider-wide bucket used by playback/search/download.
func opKey(name, op string) string {
	if op == "" {
		return name
	}
	return name + ":" + op
}

// IsCooled reports whether [name] is cooling down provider-wide. Calls to a
// cooled provider should be skipped fast instead of re-hitting its API.
func IsCooled(name string) bool {
	return isCooledKey(opKey(name, ""))
}

// IsCooledOp reports whether provider [name] is cooling down within the given
// operation class [op] (e.g. "feed", "detail"). Independent of the
// provider-wide bucket.
func IsCooledOp(name, op string) bool {
	return isCooledKey(opKey(name, op))
}

func isCooledKey(key string) bool {
	mu.Lock()
	defer mu.Unlock()
	return time.Now().Before(cooled[key])
}

// MarkError cools [name] down provider-wide when [errMsg] indicates a
// rate-limit (HTTP 429, "too many requests", "rate limit"), a
// temporarily-unavailable provider, or a non-streamable encrypted result.
// Repeated events while already cooled double the remaining window (bounded by
// maxCooldownDur); non-matching errors leave the provider untouched so a plain
// "no results" never trips the breaker.
func MarkError(name, errMsg string) {
	markErrorKey(opKey(name, ""), errMsg)
}

// MarkOpError cools [name] down only within operation class [op]. The
// provider-wide bucket (and other op buckets) are left untouched.
func MarkOpError(name, op, errMsg string) {
	markErrorKey(opKey(name, op), errMsg)
}

func markErrorKey(key, errMsg string) {
	if !rateLimitedOrBlocked(errMsg) {
		return
	}
	mu.Lock()
	defer mu.Unlock()
	now := time.Now()
	if until, ok := cooled[key]; ok && now.Before(until) {
		d := time.Until(until) * 2
		if d < cooldownDur {
			d = cooldownDur
		}
		if d > maxCooldownDur {
			d = maxCooldownDur
		}
		cooled[key] = now.Add(d)
		return
	}
	cooled[key] = now.Add(cooldownDur + time.Duration(rand.Int63n(int64(maxJitter+1))))
}

// maxJitter spreads identical initial windows so a burst of 429s across many
// concurrent tracks doesn't make every provider re-cool and retry in lockstep.
const maxJitter = 15 * time.Second

// MarkOk removes the provider-wide cooldown for [name] after a successful
// operation so a recovered provider is used again immediately.
func MarkOk(name string) {
	markOkKey(opKey(name, ""))
}

// MarkOpOk removes the cooldown for [name] within operation class [op] only.
func MarkOpOk(name, op string) {
	markOkKey(opKey(name, op))
}

// markOkKey removes the cooldown for [key] after a successful operation so a
// recovered provider is used again immediately.
func markOkKey(key string) {
	mu.Lock()
	defer mu.Unlock()
	delete(cooled, key)
}

// ProviderStatus holds cooldown information for a single provider.
type ProviderStatus struct {
	Name    string `json:"name"`
	Cooled  bool   `json:"cooled"`
	Seconds int    `json:"seconds"` // remaining cooldown seconds
}

// GetAllStatus returns the cooldown status of all currently-cooled providers.
func GetAllStatus() []ProviderStatus {
	mu.Lock()
	defer mu.Unlock()
	now := time.Now()
	var result []ProviderStatus
	for key, until := range cooled {
		if now.Before(until) {
			secs := int(time.Until(until).Seconds()) + 1
			result = append(result, ProviderStatus{Name: key, Cooled: true, Seconds: secs})
		} else {
			delete(cooled, key)
		}
	}
	return result
}

// rateLimitedOrBlocked reports whether [errMsg] matches a condition that
// warrants cooling the provider down.
func rateLimitedOrBlocked(errMsg string) bool {
	if errMsg == "" {
		return false
	}
	e := strings.ToLower(errMsg)
	for _, marker := range []string{
		"429",
		"too many requests",
		"rate limit",
		"temporarily unavailable",
		"client decryption",
		"encriptado",
		// Access-gated responses (anonymous web sessions blocked / session-less
		// APIs): qobuz-web returns 403 until signed, amazon's anonymous search
		// returns a login page, tidal/bot checks 403. Treating these like
		// rate-limits stops the per-track walk from hammering a source that
		// currently cannot serve this app. NOTE: "verification required" is
		// deliberately NOT here — a verify error is a fixable state (complete
		// the challenge), not a rate-limit, and the client opens the verify
		// modal when it surfaces.
		"403",
		"forbidden",
		"blocked",
		"bot detection",
		"captcha",
	} {
		if strings.Contains(e, marker) {
			return true
		}
	}
	return false
}
