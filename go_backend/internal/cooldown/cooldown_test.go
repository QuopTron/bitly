package cooldown

import (
	"testing"
	"time"
)

func TestMarkError_OnlyRateLimitMarkersCool(t *testing.T) {
	// A plain "no results" or generic failure must never trip the breaker.
	MarkError("deezer", "no results found")
	MarkError("deezer", "ext call failed: boom")
	if IsCooled("deezer") {
		t.Fatal("generic errors must not cool the provider down")
	}

	MarkError("deezer", "HTTP 429 for /dl/dzr")
	if !IsCooled("deezer") {
		t.Fatal("HTTP 429 must cool the provider down")
	}
	MarkOk("deezer")
	if IsCooled("deezer") {
		t.Fatal("MarkOk must clear the cooldown")
	}

	MarkError("qobuz-web", "Provider temporarily unavailable")
	if !IsCooled("qobuz-web") {
		t.Fatal("temporarily unavailable must cool the provider down")
	}
	MarkOk("qobuz-web")

	MarkError("amazon", "client decryption failure")
	if !IsCooled("amazon") {
		t.Fatal("encrypted/decryption failures must cool the provider down")
	}
	MarkOk("amazon")
}

func TestMarkError_BackoffExtendsWindow(t *testing.T) {
	MarkError("tidal-web", "HTTP 429 rate limited")
	firstUntil := cooled["tidal-web"]
	if time.Now().After(firstUntil) {
		t.Fatal("expected cooldown deadline in the future")
	}

	// A second event while still cooled must extend (double) the deadline.
	MarkError("tidal-web", "HTTP 429 rate limited")
	secondUntil := cooled["tidal-web"]
	if !secondUntil.After(firstUntil) {
		t.Fatalf("expected backoff to extend the deadline: %v -> %v", firstUntil, secondUntil)
	}

	// But never beyond the cap.
	maxGap := 4*time.Minute + 5*time.Second
	if time.Until(secondUntil) > maxGap {
		t.Fatalf("backoff exceeded cap: %v", time.Until(secondUntil))
	}
	MarkOk("tidal-web")
}

func TestOpBuckets_AreIsolated(t *testing.T) {
	// A feed 429 must cool ONLY the feed bucket, never the provider-wide
	// bucket nor the detail bucket.
	MarkOpError("amazon", "feed", "HTTP 429 for showHomeBrowse")
	if !IsCooledOp("amazon", "feed") {
		t.Fatal("feed bucket should be cooled")
	}
	if IsCooled("amazon") {
		t.Fatal("feed 429 must not cool the provider-wide bucket")
	}
	if IsCooledOp("amazon", "detail") {
		t.Fatal("feed 429 must not cool the detail bucket")
	}

	// Clearing the feed bucket must not affect anything else.
	MarkOpOk("amazon", "feed")
	if IsCooledOp("amazon", "feed") {
		t.Fatal("MarkOpOk must clear the feed bucket")
	}

	// A provider-wide 429 must NOT cool any op bucket.
	MarkError("amazon", "HTTP 429 for /dl/dzr")
	if !IsCooled("amazon") {
		t.Fatal("provider-wide bucket should be cooled")
	}
	if IsCooledOp("amazon", "detail") || IsCooledOp("amazon", "feed") {
		t.Fatal("provider-wide 429 must not cool op buckets")
	}
	MarkOk("amazon")

	// Detail bucket is independent from feed bucket.
	MarkOpError("deezer", "detail", "Provider temporarily unavailable")
	if !IsCooledOp("deezer", "detail") {
		t.Fatal("detail bucket should be cooled")
	}
	if IsCooledOp("deezer", "feed") || IsCooled("deezer") {
		t.Fatal("detail 429 must not cool other buckets")
	}
	MarkOpOk("deezer", "detail")
}

func TestRateLimitedOrBlocked_Markers(t *testing.T) {
	for _, msg := range []string{
		"HTTP 429 for /search",
		"Too many requests, slow down",
		"Rate limit exceeded",
		"Provider temporarily unavailable",
		"client decryption required",
		"stream encriptado no reproducible",
		// VERIFY_REQUIRED from signed-session providers must cool the provider
		// (short window) so the fallback stops attempting it dozens of times
		// per track, burning the streaming budget on a source that cannot serve
		// until the user completes the challenge.
		"getDownloadUrl failed: VERIFY_REQUIRED",
		"verification required on tidal-web",
		"precondition required",
		"HTTP 428",
	} {
		if !rateLimitedOrBlocked(msg) {
			t.Errorf("expected %q to be treated as rate-limited/blocked", msg)
		}
	}
	if rateLimitedOrBlocked("") {
		t.Error("empty message must not match")
	}
}

func TestVerificationRequired_ShortWindow(t *testing.T) {
	MarkOpError("tidal-web", "download", "getDownloadUrl failed: VERIFY_REQUIRED")
	if !IsCooledOp("tidal-web", "download") {
		t.Fatal("verification error must cool the download bucket")
	}
	// The window must be short (45s base + jitter), not the full rate-limit
	// window, so a session completed in the verify modal is retried quickly.
	if IsCooledOp("tidal-web", "feed") || IsCooled("tidal-web") {
		t.Fatal("verification cooldown must stay in the op bucket, not provider-wide")
	}
	MarkOpOk("tidal-web", "download")
	if IsCooledOp("tidal-web", "download") {
		t.Fatal("MarkOpOk must clear the verification cooldown")
	}
}
