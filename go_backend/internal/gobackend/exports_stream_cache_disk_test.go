package gobackend

import (
	"path/filepath"
	"testing"
)

func TestStreamFailCacheVerificationNotPersisted(t *testing.T) {
	dir := t.TempDir()
	old := downloadDir
	downloadDir = dir
	defer func() { downloadDir = old }()

	streamFailMu.Lock()
	streamFailCache = map[string]streamFailEntry{}
	streamFailMu.Unlock()

	// A definitive failure first — this is what actually creates the file.
	streamFailSet("isrc:DEF1", "all providers failed", "no_stream", "soundcloud")

	// A VERIFY_REQUIRED failure must NOT be written to disk: completing the
	// verification can make the track playable, so it should be retried after
	// the short memory TTL instead of persisting a stale block.
	streamFailSet("isrc:VER1", "verification required", "verification_required", "deezer")

	path := streamFailPersistPathLocked()
	entries, err := streamFailDiskReadLocked(path)
	if err != nil {
		t.Fatalf("expected persisted file (definitive failure was written): %v", err)
	}
	// The verification key must not be on disk, while the definitive one is.
	if _, ok := entries["isrc:VER1"]; ok {
		t.Fatal("verification_required failure must not be persisted")
	}
	if _, ok := entries["isrc:DEF1"]; !ok {
		t.Fatal("definitive no_stream failure should still be persisted")
	}

	// A verification failure must NOT be cached in memory either: it is
	// recoverable (completing the challenge makes the track playable), so the
	// next tap must re-run the provider walk instead of returning the stale
	// failure right after the user finishes verifying.
	if _, hit := streamFailGet("isrc:VER1"); hit {
		t.Fatal("verification_required failure must not be cached in memory")
	}
}

func TestStreamFailCacheTransientServerErrorNotCached(t *testing.T) {
	// A transient 5xx (e.g. Tidal's relay returning HTTP 502) is NOT definitive:
	// the server may recover seconds later, or another provider (deezer, after
	// verification) can serve the track — so it must never be fail-cached,
	// otherwise every subsequent tap fails instantly with the stale error.
	streamFailSet("isrc:502X", "Quality DOLBY_ATMOS failed | HTTP 502 for /dl/tid", "", "")
	if _, hit := streamFailGet("isrc:502X"); hit {
		t.Fatal("transient 5xx failure must not be cached in memory")
	}

	// Timeouts / gateway errors are equally transient.
	for _, msg := range []string{
		"HTTP 503 for /dl/tid",
		"bad gateway",
		"request timed out",
		"connection reset by peer",
	} {
		if !esErrorServidorTransitorio(msg) {
			t.Fatalf("expected transient detection for %q", msg)
		}
		streamFailSet("isrc:"+msg, msg, "", "")
		if _, hit := streamFailGet("isrc:" + msg); hit {
			t.Fatalf("transient failure must not be cached: %q", msg)
		}
	}

	// Definitive failures are still cached (that is the cache's purpose).
	streamFailSet("isrc:DEF2", "no provider has this track", "no_stream", "")
	if _, hit := streamFailGet("isrc:DEF2"); !hit {
		t.Fatal("definitive failure should still be cached")
	}
	streamFailClear("isrc:DEF2")
}

func TestStreamFailCacheFileColocated(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "nested", "dir")
	old := downloadDir
	downloadDir = dir
	defer func() { downloadDir = old }()

	want := filepath.Join(dir, ".stream_cache", "stream_failures.json")
	got := streamFailPersistPathLocked()
	if got != want {
		t.Fatalf("persist path mismatch: got %q want %q", got, want)
	}
}
