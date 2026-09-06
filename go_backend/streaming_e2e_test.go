package gobackend

import (
	"encoding/json"
	"os"
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
)

// TestStreamDiagE2E runs the REAL GetStreamPackage RPC against tracks whose
// preferred source is a preview/DRM provider (spotify-web / apple-music /
// amazon), exactly as the app taps them from search / feed / mi espacio. It
// measures how long the fast streaming path takes and which provider wins, so
// we can verify the rescue-by-identifiers logic works for non-YouTube sources.
func TestStreamDiagE2E(t *testing.T) {
	if os.Getenv("BITLY_STREAM_DIAG") == "" {
		t.Skip("set BITLY_STREAM_DIAG=1 to run the real-network stream diagnostic")
	}
	InitGlobalState()
	InitExtensionSystem(`{"extensions_dir":"","data_dir":""}`)
	LoadExtensionsFromDir(`{"dir_path":""}`)

	// (label, json payload). isrc/ids + names taken from real app log hits.
	cases := []struct{ label, payload string }{
		{
			"spotify-web→Columbia Quevedo (BK4DA2310533)",
			`{"preferredProvider":"spotify-web","trackID":"6XbtvPmIpyCbjuT0e8cQtp","quality":"high","fetchLyrics":"false","trackName":"Columbia","artistName":"Quevedo","isrc":"BK4DA2310533","durationMs":212000,"spotifyId":"6XbtvPmIpyCbjuT0e8cQtp","allowFallback":false}`,
		},
		{
			"apple-music→El Clavo Remix (USSD11800222)",
			`{"preferredProvider":"apple-music","trackID":"2UU1XiId16k6Bz1g8M9hnC","quality":"high","fetchLyrics":"false","trackName":"El Clavo (feat. Maluma) - Remix","artistName":"Prince Royce, Maluma","isrc":"USSD11800222","durationMs":204000,"spotifyId":"2UU1XiId16k6Bz1g8M9hnC","allowFallback":false}`,
		},
		{
			"amazon→Percuma Mahalini (name only, no isrc)",
			`{"preferredProvider":"amazon","trackID":"B0D9XYZ","quality":"high","fetchLyrics":"false","trackName":"Percuma","artistName":"Mahalini","isrc":"","durationMs":250000,"allowFallback":false}`,
		},
		{
			"apple-music→neo roneo (USWB12403528)",
			`{"preferredProvider":"apple-music","trackID":"7zoVtzzASRtacCvgQKLFaS","quality":"high","fetchLyrics":"false","trackName":"neo roneo","artistName":"rusowsky, LATIN MAFIA","isrc":"USWB12403528","durationMs":186000,"spotifyId":"7zoVtzzASRtacCvgQKLFaS","allowFallback":false}`,
		},
		{
			"RE-RUN same→Columbia (client-health warm)",
			`{"preferredProvider":"spotify-web","trackID":"6XbtvPmIpyCbjuT0e8cQtp","quality":"high","fetchLyrics":"false","trackName":"Columbia","artistName":"Quevedo","isrc":"BK4DA2310533","durationMs":212000,"spotifyId":"6XbtvPmIpyCbjuT0e8cQtp","allowFallback":false}`,
		},
	}

	for _, c := range cases {
		start := time.Now()
		out := GetStreamPackage(c.payload)
		elapsed := time.Since(start).Round(time.Millisecond)

		var res map[string]any
		_ = json.Unmarshal([]byte(out), &res)
		url, _ := res["audioUrl"].(string)
		prov, _ := res["provider"].(string)
		errStr, _ := res["error"].(string)
		if len(url) > 110 {
			url = url[:110] + "..."
		}
		t.Logf("[%s] TIME=%s provider=%s error=%q\n  audioUrl=%s",
			c.label, elapsed, prov, errStr, url)
	}

	// Provider health after the runs: which providers are cooled (would be
	// skipped on the user's next tap)?
	if st, err := json.Marshal(cooldown.GetAllStatus()); err == nil {
		t.Logf("cooldown after: %s", st)
	}
}
