package streaming

import (
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// stubProvider implements provider.Provider with a controllable stream
// resolution (or a never-returning one, to model a hung JS call).
type stubProvider struct {
	name     string
	resolve  func() (string, error)
	searches int
}

func (s *stubProvider) Name() string                            { return s.name }
func (s *stubProvider) SearchTracks(q string, l int) ([]provider.TrackResult, error) {
	s.searches++
	return nil, nil
}
func (s *stubProvider) SearchAlbums(q string, l int) ([]provider.AlbumResult, error)   { return nil, nil }
func (s *stubProvider) SearchArtists(q string, l int) ([]provider.ArtistResult, error) { return nil, nil }
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
	url, name := rescueRace(reg, []string{"stuck", "slow", "fast"}, 2*time.Second, 2, func(n string, p provider.Provider) string {
		u, err := p.GetStreamURL(n, "high")
		if err != nil || u == "" {
			return ""
		}
		return u
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
	url, name := rescueRace(reg, []string{"a", "b", "c"}, 500*time.Millisecond, 2, func(n string, p provider.Provider) string {
		u, err := p.GetStreamURL(n, "high")
		if err != nil || u == "" {
			return ""
		}
		return u
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

	url, name := rescueRace(reg, []string{"slow", "fast"}, time.Second, 2, func(n string, p provider.Provider) string {
		u, err := p.GetStreamURL(n, "high")
		if err != nil || u == "" {
			return ""
		}
		return u
	})
	if url != "http://fast/stream" || name != "fast" {
		t.Fatalf("expected fast/stream from fast, got %q from %q", url, name)
	}
}