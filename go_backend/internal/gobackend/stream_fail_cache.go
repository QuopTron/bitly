package gobackend

import (
	"strings"
	"time"
)

func streamFailGet(key string) (streamFailEntry, bool) {
	streamFailMu.Lock()
	defer streamFailMu.Unlock()
	e, ok := streamFailCache[key]
	if ok && time.Since(e.at) <= streamFailMemoryTTL {
		return e, true
	}
	if ok {
		// Memory copy expired — fall through to disk (may still be within the
		// longer restart window).
		delete(streamFailCache, key)
	}
	// Try the persisted copy (survives app restarts). Load it into memory so
	// el siguiente búsqueda doesn't hit disk again, y refresh su marca de tiempo so the
	// live session honors it for the full memory TTL.
	e, ok = streamFailDiskGetLocked(key)
	if ok {
		e.at = time.Now()
		streamFailCache[key] = e
		return e, true
	}
	return streamFailEntry{}, false
}

func streamFailSet(key, err, errorType, service string) {
	if key == "" {
		return
	}
	// Verification-required errors are RECOVERABLE (the user can complete the
	// Cloudflare/signed-session challenge and the track becomes playable), so
	// they must not be cached at all — neither in memory nor on disk. A stale
	// entry would keep returning the old failure right after the user finishes
	// verifying, instead of retrying the provider that just became usable.
	lower := strings.ToLower(errorType)
	if lower == "verification_required" ||
		strings.Contains(strings.ToLower(err), "verify_required") ||
		strings.Contains(strings.ToLower(err), "verification required") {
		return
	}
	// Transient server errors (5xx from a provider's relay/API, timeouts,
	// gateway hiccups) are NOT definitive: the provider may recover seconds
	// later. Caching them makes every subsequent tap fail instantly with a
	// stale error (e.g. Tidal's relay 502-ing for one song while Deezer could
	// serve it after verification) — so never cache them, memory or disk.
	if esErrorServidorTransitorio(err) {
		return
	}
	now := time.Now()
	entry := streamFailEntry{at: now, err: err, errorType: errorType, service: service}
	streamFailMu.Lock()
	streamFailCache[key] = entry
	// Persist only definitive failures (no source anywhere). Verification-
	// required errors must NOT be persisted: completing the verification can
	// make the track playable, and a stale disk entry would keep failing it.
	if errorType == "" || strings.ToLower(errorType) == "no_stream" {
		streamFailDiskSetLocked(key, entry)
	}
	streamFailMu.Unlock()
}

func streamFailClear(key string) {
	if key == "" {
		return
	}
	streamFailMu.Lock()
	defer streamFailMu.Unlock()
	delete(streamFailCache, key)
	streamFailDiskClearLocked(key)
}
