package streaming

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

func TestRescueRaceVerifyFastFails(t *testing.T) {
	reg := provider.NewRegistry()
	// A provider that resolves AFTER the budget — its stream is too late, so
	// the race must end on the verification verdict at the deadline.
	reg.Register(&stubProvider{name: "slow", resolve: func() (string, error) {
		time.Sleep(6 * time.Second)
		return "http://slow/stream", nil
	}})
	// The verify provider resolves the track but its stream needs a session.
	reg.Register(&stubProvider{name: "deezer", resolve: func() (string, error) {
		return "", fmt.Errorf("getDownloadUrl failed: VERIFY_REQUIRED")
	}})

	start := time.Now()
	url, name, verified := carreraRescue(reg, []string{"deezer", "slow"}, 4*time.Second, 2, func(n string, p provider.Provider) (string, bool) {
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
	if elapsed > 5*time.Second {
		t.Fatalf("verification verdict took %s, expected within the race budget (~4s)", elapsed)
	}
	t.Logf("verification verdict from %q in %s — at budget end, no stream landed", name, elapsed.Round(10*time.Millisecond))
}

// TestRescueRaceVerifyGraceSlowStreamWins: a real stream that lands DURING the
// grace window wins over a faster "needs session" signal — a working provider
// must never be preempted by a quick verify verdict. This is what makes a
// deezer-verify-blocked track fall back to youtube/soundcloud instead of
// failing playback.
func TestRescueRaceVerifyGraceSlowStreamWins(t *testing.T) {
	reg := provider.NewRegistry()
	// The working provider resolves slower than the verify signal but well
	// within the grace window — its stream must win.
	reg.Register(&stubProvider{name: "slow", resolve: func() (string, error) {
		time.Sleep(3 * time.Second)
		return "http://slow/stream", nil
	}})
	reg.Register(&stubProvider{name: "deezer", resolve: func() (string, error) {
		return "", fmt.Errorf("getDownloadUrl failed: VERIFY_REQUIRED")
	}})

	start := time.Now()
	url, name, verified := carreraRescue(reg, []string{"deezer", "slow"}, 6*time.Second, 2, func(n string, p provider.Provider) (string, bool) {
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

	if verified || url != "http://slow/stream" || name != "slow" {
		t.Fatalf("expected the slow stream to win, got url=%q name=%q verified=%v", url, name, verified)
	}
	if elapsed > verifyGrace {
		t.Fatalf("stream took %s, expected within verifyGrace (%s)", elapsed, verifyGrace)
	}
	t.Logf("slow stream won in %s — verify signal did not preempt a playable source", elapsed.Round(10*time.Millisecond))
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

	url, name, verified := carreraRescue(reg, []string{"deezer", "working"}, 2*time.Second, 2, func(n string, p provider.Provider) (string, bool) {
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
// the download() pipeline can serve it), rescueProviderUnaVez must abort after
// the FIRST probe instead of re-resolving the encrypted descriptor for every
// quality. Previously the generic "stream not available" error matched no
// cooldown marker, so deezer was re-probed across every rescue phase (7
// qualities x 4 phases), saturating the race slots and delaying providers that
// COULD stream (qobuz-web etc.) by tens of seconds.
