package gobackend

import (
	"encoding/json"
	"os"
	"sync"
	"testing"
	"time"
)

// TestHangReproConcurrent mirrors the device failure mode: the queue preloads
// several tracks at once, so multiple GetStreamPackage calls hit the backend
// concurrently. The single-call harness returns fine; the device hung with
// concurrent calls — this reproduces that shape with a hard watchdog.
func TestHangReproConcurrent(t *testing.T) {
	if os.Getenv("BITLY_HANG_REPRO") == "" {
		t.Skip("set BITLY_HANG_REPRO=1 to run")
	}
	InitGlobalState()
	InitExtensionSystem(`{"extensions_dir":"","data_dir":""}`)
	LoadExtensionsFromDir(`{"dir_path":""}`)

	// Same tracks as the device log: Self Care + Weekend, concurrent.
	payloads := []string{
		`{"preferredProvider":"amazon","trackID":"USWB11601446","quality":"high","fetchLyrics":"false","trackName":"Self Care","artistName":"Mac Miller","isrc":"USWB11601446","durationMs":350000,"allowFallback":true}`,
		`{"preferredProvider":"amazon","trackID":"USWB11508659","quality":"high","fetchLyrics":"false","trackName":"Weekend (feat. Miguel)","artistName":"Mac Miller","isrc":"USWB11508659","durationMs":220000,"allowFallback":true}`,
		`{"preferredProvider":"amazon","trackID":"USA2P2015959","quality":"high","fetchLyrics":"false","trackName":"The Spins","artistName":"Mac Miller & Empire Of The Sun","isrc":"USA2P2015959","durationMs":195000,"allowFallback":true}`,
	}

	var wg sync.WaitGroup
	results := make(chan string, len(payloads))
	start := time.Now()
	for i, p := range payloads {
		wg.Add(1)
		go func(i int, p string) {
			defer wg.Done()
			t.Logf("[%d] CALLING at %s", i, time.Since(start).Round(10*time.Millisecond))
			out := GetStreamPackage(p)
			var parsed map[string]any
			json.Unmarshal([]byte(out), &parsed)
			prov, _ := parsed["provider"].(string)
			t.Logf("[%d] RETURNED after %s provider=%s", i, time.Since(start).Round(10*time.Millisecond), prov)
			results <- out
		}(i, p)
	}

	done := make(chan struct{})
	go func() { wg.Wait(); close(done) }()

	select {
	case <-done:
		t.Logf("ALL %d calls returned", len(payloads))
	case <-time.After(120 * time.Second):
		t.Fatalf("HANG REPRODUCED: concurrent GetStreamPackage calls did not return within 120s")
	}
}