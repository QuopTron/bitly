package gobackend

import (
	"encoding/json"
	"fmt"
	"os"
	"testing"
	"time"
)

// TestSearchDiag runs a REAL search against every registered source and prints
// the returned item-type histogram so we can see which extensions actually
// return search results and which return nothing. Temporary diagnostic.
func TestSearchDiag(t *testing.T) {
	// Network diagnostic — only runs when explicitly requested, so normal
	// `go test ./...` (CI included) never hits external APIs.
	if os.Getenv("BITLY_SEARCH_DIAG") == "" {
		t.Skip("set BITLY_SEARCH_DIAG=1 to run the network search diagnostic")
	}
	InitGlobalState()
	InitExtensionSystem(`{"extensions_dir":"","data_dir":""}`)
	LoadExtensionsFromDir(`{"dir_path":""}`)

	queries := []string{
		`{"query":"Desesperados Rauw Alejandro","limit":25,"source":"%s","type":"all"}`,
		`{"query":"Dai Dai Shakira","limit":25,"source":"%s","type":"all"}`,
	}
	// Multi-source ('Todas') — the previously broken path.
	for _, typ := range []string{"all", "tracks", "artists", "albums", "playlists"} {
		payload := fmt.Sprintf(`{"query":"Desesperados Rauw Alejandro","limit":25,"source":"","type":"%s"}`, typ)
		out := Search(payload)
		var list []FeedItemGo
		_ = json.Unmarshal([]byte(out), &list)
		hist := map[string]int{}
		for _, it := range list {
			hist[it.Type]++
		}
		t.Logf("MULTI-SOURCE TYPE=%-10s TOTAL=%d TYPES=%v", typ, len(list), hist)
	}

	for _, src := range []string{
		"deezer", "spotify-web", "apple-music", "soundcloud", "amazon",
		"qobuz-web", "tidal-web", "ytmusic-spotiflac", "pandora",
	} {
		for _, tpl := range queries {
			payload := fmt.Sprintf(tpl, src)
			start := time.Now()
			out := Search(payload)
			elapsed := time.Since(start).Round(time.Millisecond)
			var list []FeedItemGo
			_ = json.Unmarshal([]byte(out), &list)
			hist := map[string]int{}
			for _, it := range list {
				hist[it.Type]++
			}
			t.Logf("SOURCE=%-16s QUERY=%s TIME=%s TOTAL=%d TYPES=%v",
				src, payload[8:35], elapsed, len(list), hist)
		}
	}
}
