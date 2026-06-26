package handlers

import (
	"encoding/json"
	"fmt"
	"testing"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/api"
)

func TestRegisterSearch_ArtistPlaylist(t *testing.T) {
	ensureExtensionInit()

	types := []string{"artist", "playlist"}
	sources := []string{"deezer", "spotify-web", "apple-music", "soundcloud", "tidal-web", "qobuz-web", "ytmusic-spotiflac"}

	for _, searchType := range types {
		for _, source := range sources {
			items := doSearch(source, searchType, 5)
			if len(items) == 0 {
				t.Logf("❌ %s/%s: 0 results", source, searchType)
			} else {
				var names []string
				for _, item := range items {
					name, _ := item["name"].(string)
					typ, _ := item["type"].(string)
					names = append(names, fmt.Sprintf("%s(%s)", name, typ))
				}
				t.Logf("✅ %s/%s: %d results: %v", source, searchType, len(items), names)
				if len(items) > 0 {
					j, _ := json.MarshalIndent(items[0], "", "  ")
					t.Logf("   first item JSON: %s", string(j))
				}
			}
		}
	}
}

func doSearch(source, searchType string, limit int) []map[string]interface{} {
	initSearchService()
	ensureExtensionInit()

	items := make([]map[string]interface{}, 0)
	seen := make(map[string]bool)

	for _, ext := range extManager.ListExtensions() {
		if ext == nil || ext.Error != "" {
			continue
		}
		if !ext.Enabled && !extRuntime.IsLoaded(ext.ID) {
			continue
		}
		if !extRuntime.IsLoaded(ext.ID) {
			continue
		}
		if source != "" && ext.ID != source {
			continue
		}

		if extRuntime.HasMethod(ext.ID, "customSearch") {
			customResults := callExtensionCustomSearch(ext.ID, "bad bunny", searchType, limit)
			for _, r := range customResults {
				key := makeDedupKey(r, ext.ID, searchType)
				if seen[key] {
					continue
				}
				seen[key] = true
				items = append(items, mapSearchResultToItem(r, ext.ID, searchType))
				if len(items) >= limit {
					break
				}
			}
		}

		if len(items) >= limit {
			break
		}
	}

	return items
}

// Ensure the api import is used
var _ = api.ParseSearchResultsFromArray

