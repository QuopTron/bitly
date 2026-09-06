package streaming

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// stubProvider implements provider.Provider with a controllable stream
// resolution (or a never-returning one, to model a hung JS call).
type stubProvider struct {
	name     string
	resolve  func() (string, error)
	searches int
}

func (s *stubProvider) Name() string { return s.name }
func (s *stubProvider) SearchTracks(q string, l int) ([]provider.TrackResult, error) {
	s.searches++
	return nil, nil
}
func (s *stubProvider) SearchAlbums(q string, l int) ([]provider.AlbumResult, error) { return nil, nil }
func (s *stubProvider) SearchArtists(q string, l int) ([]provider.ArtistResult, error) {
	return nil, nil
}
func (s *stubProvider) SearchPlaylists(q string, l int) ([]provider.PlaylistResult, error) {
	return nil, nil
}
func (s *stubProvider) GetTrack(id string) (*provider.TrackResult, error) { return nil, nil }
func (s *stubProvider) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	return nil, nil
}
func (s *stubProvider) GetAlbum(id string) (*provider.AlbumResult, error)   { return nil, nil }
func (s *stubProvider) GetArtist(id string) (*provider.ArtistResult, error) { return nil, nil }
func (s *stubProvider) GetStreamURL(id, quality string) (string, error) {
	return s.resolve()
}

// TestRescueRaceNoDeadlockStuckWorker simulates the device hang: a previous
// race leaked a worker that never returns (a JS call stuck in a synchronous
// fetch), holding one semaphore slot forever. A second, concurrent race with
// more providers than free slots must still return within its budget instead
// of blocking on sem <- struct{}{} before its timer is created.
func TestRescueRaceNoDeadlockStuckWorker(t *testing.T) {
	release := make(chan struct{})
	defer close(release) // let leaked stuck workers exit so the test process ends
	reg := provider.NewRegistry()
	stuck := &stubProvider{name: "stuck", resolve: func() (string, error) {
		<-release // never returns during the race, like a hung JS call
		return "", nil
	}}
	slow := &stubProvider{name: "slow", resolve: func() (string, error) {
		time.Sleep(300 * time.Millisecond)
		return "http://slow/stream", nil
	}}
	fast := &stubProvider{name: "fast", resolve: func() (string, error) {
		return "http://fast/stream", nil
	}}
	reg.Register(stuck)
	reg.Register(slow)
	reg.Register(fast)

	start := time.Now()
	url, name, _ := rescueRace(reg, []string{"stuck", "slow", "fast"}, 2*time.Second, 2, func(n string, p provider.Provider) (string, bool) {
		u, err := p.GetStreamURL(n, "high")
		if err != nil || u == "" {
			return "", false
		}
		return u, false
	})
	elapsed := time.Since(start)

	if url == "" {
		t.Fatalf("expected a winning provider despite the stuck worker, got nothing")
	}
	if name == "stuck" {
		t.Fatalf("stuck provider must never win")
	}
	if elapsed > 3*time.Second {
		t.Fatalf("race took %s, should have returned within budget (~2s)", elapsed)
	}
	t.Logf("returned %q from %q in %s (stuck worker did not deadlock the race)", url, name, elapsed.Round(10*time.Millisecond))
}

// TestRescueRaceAllStuck: when every worker hangs, the race still returns
// (empty) at the budget instead of blocking forever.
func TestRescueRaceAllStuck(t *testing.T) {
	release := make(chan struct{})
	defer close(release) // let leaked stuck workers exit so the test process ends
	reg := provider.NewRegistry()
	for _, n := range []string{"a", "b", "c"} {
		reg.Register(&stubProvider{name: n, resolve: func() (string, error) {
			<-release
			return "", nil
		}})
	}

	start := time.Now()
	url, name, _ := rescueRace(reg, []string{"a", "b", "c"}, 500*time.Millisecond, 2, func(n string, p provider.Provider) (string, bool) {
		u, err := p.GetStreamURL(n, "high")
		if err != nil || u == "" {
			return "", false
		}
		return u, false
	})
	elapsed := time.Since(start)

	if url != "" || name != "" {
		t.Fatalf("expected empty result, got %q/%q", url, name)
	}
	if elapsed > 2*time.Second {
		t.Fatalf("race with all-stuck workers took %s, budget was 500ms", elapsed)
	}
	t.Logf("returned empty in %s — no deadlock", elapsed.Round(10*time.Millisecond))
}

// TestRescueRaceFastWins: the fastest provider wins within budget and order is
// honored when results tie.
func TestRescueRaceFastWins(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&stubProvider{name: "slow", resolve: func() (string, error) {
		time.Sleep(100 * time.Millisecond)
		return "http://slow/stream", nil
	}})
	reg.Register(&stubProvider{name: "fast", resolve: func() (string, error) {
		return "http://fast/stream", nil
	}})

	url, name, _ := rescueRace(reg, []string{"slow", "fast"}, time.Second, 2, func(n string, p provider.Provider) (string, bool) {
		u, err := p.GetStreamURL(n, "high")
		if err != nil || u == "" {
			return "", false
		}
		return u, false
	})
	if url != "http://fast/stream" || name != "fast" {
		t.Fatalf("expected fast/stream from fast, got %q from %q", url, name)
	}
}

// TestRescueRaceVerifyFastFails: when a provider HAS the track but needs its
// session verified (VERIFY_REQUIRED) and no other provider streams within the
// short grace, the race returns the verdict fast — instead of walking every
// provider for 10-30s before surfacing the same "verification required" error.
func TestRescueRaceVerifyFastFails(t *testing.T) {
	reg := provider.NewRegistry()
	// A working provider that resolves slower than the verify grace — it must
	// NOT mask the verification signal (in reality a working provider usually
	// wins the race; here the verify is the only fast outcome).
	reg.Register(&stubProvider{name: "slow", resolve: func() (string, error) {
		time.Sleep(3 * time.Second)
		return "http://slow/stream", nil
	}})
	// The verify provider resolves the track but its stream needs a session.
	reg.Register(&stubProvider{name: "deezer", resolve: func() (string, error) {
		return "", fmt.Errorf("getDownloadUrl failed: VERIFY_REQUIRED")
	}})

	start := time.Now()
	url, name, verified := rescueRace(reg, []string{"deezer", "slow"}, 4*time.Second, 2, func(n string, p provider.Provider) (string, bool) {
		u, err := p.GetStreamURL(n, "high")
		if err != nil {
			if strings.Contains(strings.ToLower(err.Error()), "verify_required") {
				return "", true
			}
			return "", false
		}
		return u, false
	})
	elapsed := time.Since(start)

	if !verified || name != "deezer" {
		t.Fatalf("expected verification verdict from deezer, got url=%q name=%q verified=%v", url, name, verified)
	}
	if elapsed < verifyGrace || elapsed > verifyGrace+2*time.Second {
		t.Fatalf("verification verdict took %s, expected ~verifyGrace (%s)", elapsed, verifyGrace)
	}
	t.Logf("verification verdict from %q in %s — fail-fast after grace", name, elapsed.Round(10*time.Millisecond))
}

// TestRescueRaceVerifyGraceStreamWins: a real stream that lands DURING the
// verify grace still wins over the verification signal — a working provider
// must never be preempted by a fast "needs session" verdict.
func TestRescueRaceVerifyGraceStreamWins(t *testing.T) {
	reg := provider.NewRegistry()
	// The working provider finishes within the grace window.
	reg.Register(&stubProvider{name: "working", resolve: func() (string, error) {
		time.Sleep(300 * time.Millisecond)
		return "http://working/stream", nil
	}})
	reg.Register(&stubProvider{name: "deezer", resolve: func() (string, error) {
		return "", fmt.Errorf("getDownloadUrl failed: VERIFY_REQUIRED")
	}})

	url, name, verified := rescueRace(reg, []string{"deezer", "working"}, 2*time.Second, 2, func(n string, p provider.Provider) (string, bool) {
		u, err := p.GetStreamURL(n, "high")
		if err != nil {
			if strings.Contains(strings.ToLower(err.Error()), "verify_required") {
				return "", true
			}
			return "", false
		}
		return u, false
	})
	if verified || url != "http://working/stream" || name != "working" {
		t.Fatalf("expected the working stream to win, got url=%q name=%q verified=%v", url, name, verified)
	}
}

// TestRescueProviderOnceClientDecryptionFailsFast: when the provider signals
// CLIENT_DECRYPTION_REQUIRED (deezer Blowfish FLAC — the track exists but only
// the download() pipeline can serve it), rescueProviderOnce must abort after
// the FIRST probe instead of re-resolving the encrypted descriptor for every
// quality. Previously the generic "stream not available" error matched no
// cooldown marker, so deezer was re-probed across every rescue phase (7
// qualities x 4 phases), saturating the race slots and delaying providers that
// COULD stream (qobuz-web etc.) by tens of seconds.
func TestRescueProviderOnceClientDecryptionFailsFast(t *testing.T) {
	calls := 0
	p := &stubProvider{name: "deezer", resolve: func() (string, error) {
		calls++
		return "", fmt.Errorf("getDownloadUrl failed: CLIENT_DECRYPTION_REQUIRED: stream requires client decryption")
	}}

	url, verified := rescueProviderOnce(p, "3733293352", "FLAC")
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

	url, _ := rescueProviderOnce(p, "track-123", "high")
	if url != "" {
		t.Fatalf("expected no stream, got %q", url)
	}
	// Second probe of the same provider+track must be memoized — zero calls.
	url, _ = rescueProviderOnce(p, "track-123", "high")
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
	abort, err := classifyStreamError("deezer", "CLIENT_DECRYPTION_REQUIRED: stream requires client decryption")
	if !abort || err == nil {
		t.Fatalf("expected abort with error, got abort=%v err=%v", abort, err)
	}
	if cooldown.IsCooled("deezer") {
		t.Fatalf("client-decryption must not cool deezer provider-wide (download pipeline and search still need it)")
	}
}
