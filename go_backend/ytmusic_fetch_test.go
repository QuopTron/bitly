package gobackend

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"testing"
	"time"
)

// TestYTMusicResolveAndFetch resolves a YouTube stream through the extension
// (same Go HTTP stack the app uses) and then fetches the resolved URL through
// the SAME Go stack — proving whether the Go client can open its own URLs
// (the device showed curl OK but mpv 403; this isolates the Go network path).
// Run: cd go_backend && BITLY_YT_FETCH=1 go test -run TestYTMusicResolveAndFetch -v
func TestYTMusicResolveAndFetch(t *testing.T) {
	if os.Getenv("BITLY_YT_FETCH") == "" {
		t.Skip("set BITLY_YT_FETCH=1 to run")
	}
	videoID := os.Getenv("BITLY_YT_VIDEO")
	if videoID == "" {
		videoID = "dQw4w9WgXcQ"
	}
	InitGlobalState()
	InitExtensionSystem(`{"extensions_dir":"","data_dir":""}`)
	LoadExtensionsFromDir(`{"dir_path":""}`)

	p := fmt.Sprintf(`{"preferredProvider":"ytmusic-spotiflac","trackID":"%s","quality":"high","fetchLyrics":"false","trackName":"test","artistName":"artist","isrc":"","durationMs":200000,"allowFallback":false}`, videoID)
	out2 := GetStreamPackage(p)
	var parsed map[string]any
	_ = json.Unmarshal([]byte(out2), &parsed)
	url, _ := parsed["audioUrl"].(string)
	t.Logf("resolved URL len=%d provider=%v", len(url), parsed["provider"])
	if url == "" {
		t.Fatalf("no URL resolved: %v", parsed["error"])
	}

	// Now fetch that exact URL through a plain Go HTTP client (same stack).
	client := &http.Client{Timeout: 15 * time.Second}
	for i, rng := range []string{"bytes=0-0", "bytes=0-100000"} {
		req, err := http.NewRequest("GET", url, nil)
		if err != nil {
			t.Fatal(err)
		}
		req.Header.Set("Range", rng)
		req.Header.Set("User-Agent", "com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip")
		resp, err := client.Do(req)
		if err != nil {
			t.Logf("fetch %d (%s): ERROR %v", i, rng, err)
			continue
		}
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 256))
		resp.Body.Close()
		t.Logf("fetch %d (%s): status=%d ct=%s body=%q", i, rng, resp.StatusCode, resp.Header.Get("Content-Type"), string(body))
	}
}