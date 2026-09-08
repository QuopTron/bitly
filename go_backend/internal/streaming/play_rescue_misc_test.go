package streaming

import (
	"fmt"
	"testing"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
)

func TestRescueProviderOnceClientDecryptionFailsFast(t *testing.T) {
	calls := 0
	p := &stubProvider{name: "deezer", resolve: func() (string, error) {
		calls++
		return "", fmt.Errorf("getDownloadUrl failed: CLIENT_DECRYPTION_REQUIRED: stream requires client decryption")
	}}

	url, verified := rescueProviderUnaVez(p, "3733293352", "FLAC")
	if url != "" || verified {
		t.Fatalf("expected empty result, got url=%q verified=%v", url, verified)
	}
	if calls != 1 {
		t.Fatalf("client-decryption provider was probed %d times, expected exactly 1 (fail fast, no per-quality re-resolve)", calls)
	}
}

// TestRescueProviderOnceClientDecryptionMemo: once a provider signals client
// decryption for a track, later phases (ISRC race, name-search race) skip it
// instantly via the memo instead of re-probing.
func TestRescueProviderOnceClientDecryptionMemo(t *testing.T) {
	calls := 0
	p := &stubProvider{name: "deezer", resolve: func() (string, error) {
		calls++
		return "", fmt.Errorf("getDownloadUrl failed: CLIENT_DECRYPTION_REQUIRED")
	}}

	url, _ := rescueProviderUnaVez(p, "track-123", "high")
	if url != "" {
		t.Fatalf("expected no stream, got %q", url)
	}
	// Second probe of the same provider+track must be memoized — zero calls.
	url, _ = rescueProviderUnaVez(p, "track-123", "high")
	if url != "" {
		t.Fatalf("expected no stream on memoized probe, got %q", url)
	}
	if calls != 1 {
		t.Fatalf("memoized provider+track probed %d times, expected 1 total", calls)
	}
}

// TestClassifyStreamErrorDoesNotCoolDeezer: a client-decryption verdict must
// NOT cool the provider provider-wide — deezer's download() (Blowfish
// decryption) remains the best DOWNLOAD source and must stay probeable by the
// download pipeline, and search must keep returning deezer results.
func TestClassifyStreamErrorDoesNotCoolDeezer(t *testing.T) {
	cooldown.MarkOk("deezer")
	abort, err := clasificarErrorStream("deezer", "CLIENT_DECRYPTION_REQUIRED: stream requires client decryption")
	if !abort || err == nil {
		t.Fatalf("expected abort with error, got abort=%v err=%v", abort, err)
	}
	if cooldown.IsCooled("deezer") {
		t.Fatalf("client-decryption must not cool deezer provider-wide (download pipeline and search still need it)")
	}
}
