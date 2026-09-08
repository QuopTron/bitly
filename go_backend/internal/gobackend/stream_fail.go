package gobackend

import (
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/download"
)

// streamFailCache remembers tracks whose stream resolution failed across every
// provider (the full fallback walk — 10-30s of provider probes, name searches
// and mirror attempts). Re-tapping the same track within the TTL returns the
// cached error in milliseconds instead of re-walking the whole chain for a
// result that just failed seconds ago. Short TTL + clear-on-success means a
// provider that recovers is retried soon.
var (
	streamFailMu    sync.Mutex
	streamFailCache = map[string]streamFailEntry{}
)

type streamFailEntry struct {
	at        time.Time
	err       string
	errorType string
	service   string
}

// streamFailMemoryTTL is how long a failure is honored within a live session
// (fast re-taps). streamFailDiskTTL is how long a failure survives restarts —
// long enough that a dead track (age-blocked video, all mirrors down) is not
// re-walked on every cold start, but short enough that a provider that comes
// back is retried soon. Verification-required failures are never persisted
// (completing the verification can make the track playable), only definitive
// "no source anywhere" results.
const (
	streamFailMemoryTTL = 90 * time.Second
	streamFailDiskTTL   = 20 * time.Minute
)

// streamFailPersistName is the JSON file kept inside the stream cache dir.
const streamFailPersistName = "stream_failures.json"

// streamFailPersistPathLocked derives the fail-cache file location from the
// live download dir (the same base streamCacheDirPath uses). Caller must hold
// streamFailMu.
func streamFailPersistPathLocked() string {
	base := downloadDir
	if base == "" {
		base = download.GlobalOutputDir()
	}
	if base == "" {
		return "" // no writable dir configured yet — skip persistence
	}
	return filepath.Join(base, ".stream_cache", streamFailPersistName)
}

// isTransientServerError reports whether [err] describes a temporary server
// failure (HTTP 5xx, gateway errors, timeouts) rather than a definitive "this
// track is not available anywhere" verdict. Transient failures must not be
// fail-cached: the source may recover (or the track may be servable by a
// verification-pending provider), so the next tap should re-attempt instead of
// instantly replaying a stale error.
func esErrorServidorTransitorio(err string) bool {
	if err == "" {
		return false
	}
	e := strings.ToLower(err)
	for _, marker := range []string{
		"http 500", "http 501", "http 502", "http 503", "http 504",
		"http 505", "http 511",
		"bad gateway", "gateway timeout", "service unavailable",
		"temporarily unavailable", "connection reset", "connection refused",
		"connection timed out", "timeout", "timed out", "no route to host",
		"server error", "upstream", "overloaded",
	} {
		if strings.Contains(e, marker) {
			return true
		}
	}
	return false
}

// deezerCanServeByISRC reports whether deezer's PUBLIC metadata API resolves
// Este exact isrc — free, sin signed sesión necesario. cuando verdadero, el solo thing// standing between the user and the song is their deezer session verification:
// el aplicación debería open el verificación modal en su lugar de showing un dead-fin// error, because completing it makes the song play.
func deezerPuedeServirPorISRC(isrc string) bool {
	if isrc == "" || reg == nil {
		return false
	}
	p := reg.Get("deezer")
	if p == nil {
		return false
	}
	// A cooled deezer es silently omitido por el respaldo walk (call() devuelve
	// nil, nil), which masks the VERIFY_REQUIRED it would surface. This probe
	// is the LAST chance before giving up: clear the cooldown (both buckets)
	// so it actually runs, and leave deezer un-cooled for the retry that
	// follows once the user completes the verification.
	cooldown.MarkOk(p.Name())
	cooldown.MarkOpOk(p.Name(), "download")
	t, err := p.GetTrackByISRC(isrc)
	return err == nil && t != nil && t.ID != ""
}

// streamFailKey builds a stable identity for a track: the strongest identifier
// wins (ISRC, then any cross-provider id, then the raw track id).
func streamFailKey(p ...string) string {
	for _, v := range p {
		if v != "" {
			return v
		}
	}
	return ""
}
