package gobackend

import (
	"encoding/json"
	"fmt"
	"os"
	"testing"
	"time"
)

// TestYTMusicChain traces the InnerTube client chain for a real video ID so we
// can see exactly which clients succeed/fail and whether the URL probe runs.
// Run: cd go_backend && BITLY_YT_CHAIN=1 go test -run TestYTMusicChain -v
func TestYTMusicChain(t *testing.T) {
	if os.Getenv("BITLY_YT_CHAIN") == "" {
		t.Skip("set BITLY_YT_CHAIN=1 to run")
	}
	videoID := os.Getenv("BITLY_YT_VIDEO")
	if videoID == "" {
		videoID = "MxLnRDLcINU" // any real music video id
	}
	InitGlobalState()
	InitExtensionSystem(`{"extensions_dir":"","data_dir":""}`)
	LoadExtensionsFromDir(`{"dir_path":""}`)

	// Run the full GetStreamPackage with the video id as the track id and
	// ytmusic-spotiflac as the preferred provider (fast streaming path, no
	// download fallback — exactly what the app's background preload does).
	p := fmt.Sprintf(`{"preferredProvider":"ytmusic-spotiflac","trackID":"%s","quality":"high","fetchLyrics":"false","trackName":"test","artistName":"artist","isrc":"","durationMs":200000,"allowFallback":false}`, videoID)
	start := time.Now()
	out2 := GetStreamPackage(p)
	var parsed map[string]any
	_ = json.Unmarshal([]byte(out2), &parsed)
	t.Logf("GetStreamPackage after %s: audioUrl=%v error=%v provider=%v needsDecryption=%v",
		time.Since(start).Round(10*time.Millisecond), parsed["audioUrl"], parsed["error"], parsed["provider"], parsed["needsDecryption"])
}