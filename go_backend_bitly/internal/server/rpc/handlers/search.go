package handlers

import (
	"fmt"
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/search"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/api"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/providers"
)

var (
	globalSearchService *search.Service
	globalRegistry      *core.ProviderRegistry
)

func initSearchService() {
	if globalSearchService != nil {
		return
	}
	globalRegistry = core.NewProviderRegistry()
	providers.RegisterAllBuiltin(globalRegistry)
	globalSearchService = search.NewService(globalRegistry)
}

func RegisterSearchHandlers(reg *rpc.Registry) {
	registerSearch(reg)
	registerSearchAvailability(reg)
}

// extensionFilter returns the filter value an extension expects for a given search type.
// Different extensions use different conventions (singular vs plural, or custom like "songs").
func extensionFilter(extID, searchType string) string {
	// Per-extension overrides for non-standard filter values
	overrides := map[string]map[string]string{
		// Amazon uses "songs" instead of "tracks"/"track"
		"amazon": {
			"track":    "songs",
			"album":    "albums",
			"artist":   "artists",
			"playlist": "playlists",
		},
		// Deezer uses singular convention
		"deezer": {
			"track":    "track",
			"album":    "album",
			"artist":   "artist",
			"playlist": "playlist",
		},
		// Qobuz uses singular convention (no playlist support)
		"qobuz-web": {
			"track":  "track",
			"album":  "album",
			"artist": "artist",
		},
		// Tidal uses singular convention
		"tidal-web": {
			"track":    "track",
			"album":    "album",
			"artist":   "artist",
			"playlist": "playlist",
		},
	}
	if extMap, ok := overrides[extID]; ok {
		if f, ok := extMap[searchType]; ok {
			return f
		}
	}
	// Default: plural convention (apple-music, soundcloud, spotify-web, ytmusic-spotiflac, etc.)
	switch searchType {
	case "track":
		return "tracks"
	case "album":
		return "albums"
	case "artist":
		return "artists"
	case "playlist":
		return "playlists"
	}
	return ""
}

// callExtensionCustomSearch invokes the "customSearch" method on an extension
// with the given search type and parses the response into SearchResult items.
func callExtensionCustomSearch(extID, query, searchType string, limit int) []api.SearchResult {
	filter := extensionFilter(extID, searchType)

	options := map[string]interface{}{
		"limit": limit,
	}
	if filter != "" {
		options["filter"] = filter
	}

	callResult, err := extRuntime.CallMethod(extID, "customSearch", query, options)
	if err != nil {
		fmt.Printf("[Search] customSearch %q %s/%s error: %v\n", extID, searchType, filter, err)
		return nil
	}
	if callResult == nil || callResult.Value == nil {
		fmt.Printf("[Search] customSearch %q %s/%s returned nil\n", extID, searchType, filter)
		return nil
	}

	// Try direct array of SearchResult
	if arr, ok := callResult.Value.([]interface{}); ok {
		results := api.ParseSearchResultsFromArray(arr)
		fmt.Printf("[Search] customSearch %q %s/%s returned %d results (array)\n", extID, searchType, filter, len(results))
		return results
	}

	// Try wrapper with tracks / results / items key
	if wrapper, ok := callResult.Value.(map[string]interface{}); ok {
		for _, key := range []string{"results", "items", "tracks"} {
			if arr, ok := wrapper[key].([]interface{}); ok && len(arr) > 0 {
				results := api.ParseSearchResultsFromArray(arr)
				fmt.Printf("[Search] customSearch %q %s/%s returned %d results (wrapper.%s)\n", extID, searchType, filter, len(results), key)
				return results
			}
		}
		fmt.Printf("[Search] customSearch %q %s/%s returned wrapper but no recognized key; keys=%v\n", extID, searchType, filter, mapKeys(wrapper))
		return nil
	}

	fmt.Printf("[Search] customSearch %q %s/%s unexpected type %T: %v\n", extID, searchType, filter, callResult.Value, truncateStr(callResult.RawJSON, 200))
	return nil
}

// mapKeys returns the keys of a map for debug logging.
func mapKeys(m map[string]interface{}) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	return keys
}

// truncateStr truncates a string to maxLen characters.
func truncateStr(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
}

// trySearchTracksFlexible calls searchTracks(query, limit) with separate arguments.
// Extensions define function searchTracks(query, limit), NOT searchTracks({query, limit}).
// Passing an object as the first arg would make query="[object Object]" in JS.
func trySearchTracksFlexible(extID, query string, limit int) []api.SearchResult {
	tracks, err := extClient.SearchTracks(extID, query, limit)
	if err == nil && len(tracks) > 0 {
		return tracks
	}
	return nil
}

// mapSearchResultToItem converts an api.SearchResult into a flat response map,
// including all non-empty fields (matching upstream ExtTrackMetadata pass-through).
func mapSearchResultToItem(r api.SearchResult, extID, searchType string) map[string]interface{} {
	cover := r.CoverURL
	if cover == "" {
		cover = r.Images
	}

	item := map[string]interface{}{
		"id":        r.ID,
		"type":      searchType,
		"name":      r.Name,
		"source":    extID,
		"cover_url": cover,
	}
	addNonEmpty(item, "artists", r.Artists)
	addNonEmpty(item, "album_name", r.AlbumName)
	addNonEmpty(item, "album_artist", r.AlbumArtist)
	addNonEmpty(item, "album_id", r.AlbumID)
	addNonEmpty(item, "artist_id", r.ArtistID)
	addNonEmpty(item, "release_date", r.ReleaseDate)
	addNonEmpty(item, "owner", r.Owner)
	addNonEmpty(item, "isrc", r.ISRC)
	addNonEmpty(item, "item_type", r.ItemType)
	addNonEmpty(item, "album_type", r.AlbumType)
	addNonEmpty(item, "provider_id", r.ProviderID)
	addNonEmpty(item, "label", r.Label)
	addNonEmpty(item, "genre", r.Genre)
	addNonEmpty(item, "composer", r.Composer)
	addNonEmpty(item, "audio_quality", r.AudioQuality)
	addNonEmpty(item, "audio_modes", r.AudioModes)
	if r.DurationMS != 0 {
		item["duration_ms"] = r.DurationMS
	}
	if r.TotalTracks != 0 {
		item["total_tracks"] = r.TotalTracks
	}
	if r.TrackNumber != 0 {
		item["track_number"] = r.TrackNumber
	}
	if r.DiscNumber != 0 {
		item["disc_number"] = r.DiscNumber
	}
	return item
}

func addNonEmpty(m map[string]interface{}, key, value string) {
	if value != "" {
		m[key] = value
	}
}

// makeDedupKey returns a unique key for deduplication based on search type.
func makeDedupKey(r api.SearchResult, extID, searchType string) string {
	switch searchType {
	case "album":
		// Dedup albums by AlbumName + Artists + source
		return r.AlbumName + "|" + r.Artists + "|" + extID
	case "artist":
		// Dedup artists by ID + source (Artists field may be empty)
		return r.ID + "|" + extID
	case "playlist":
		return r.ID + "|" + extID
	default:
		return r.ID + "|" + extID
	}
}

func registerSearch(reg *rpc.Registry) {
	reg.Register("search", func(params map[string]interface{}) (interface{}, error) {
		fmt.Printf("[SEARCH-V2] registerSearch called with query=%q type=%q\n", rpc.Sp(params, "query"), rpc.Sp(params, "type"))
		initSearchService()
		query := rpc.Sp(params, "query")
		if query == "" {
			return []map[string]interface{}{}, nil
		}
		limit := rpc.Sn(params, "limit")
		if limit <= 0 || limit > 50 {
			limit = 20
		}
		searchType := rpc.Sp(params, "type")
		if searchType == "" {
			searchType = "track"
		}
		source := rpc.Sp(params, "source")

		items := make([]map[string]interface{}, 0)
		seen := make(map[string]bool)

		// ─── JS Extensions (for ALL types: track, album, artist, playlist) ───
		// Note: Built-in Go providers (Deezer/Tidal/Qobuz) are NOT used here
		// because their SearchAll returns ALL types mixed together regardless of
		// the requested type. JS extensions handle per-type filtering correctly
		// via their customSearch() implementations.
		// Legacy single-type search is available via the "searchTracks" RPC.
		ensureExtensionInit()
		for _, ext := range extManager.ListExtensions() {
			if ext == nil || ext.Error != "" {
				continue
			}
			// Allow loaded extensions even if not explicitly enabled
			// (they are registered with Enabled=false by default)
			if !ext.Enabled && !extRuntime.IsLoaded(ext.ID) {
				continue
			}
			if !strings.Contains(ext.Type, "metadata_provider") &&
				!strings.Contains(ext.Type, "download_provider") {
				continue
			}
			if !extRuntime.IsLoaded(ext.ID) {
				continue
			}

			// Source filter
			if source != "" && ext.ID != source {
				continue
			}

				// ── Phase 1: Try customSearch first (for ALL types including tracks) ──
			var customResults []api.SearchResult
			if extRuntime.HasMethod(ext.ID, "customSearch") {
				customResults = callExtensionCustomSearch(ext.ID, query, searchType, limit)
			}

			if len(customResults) > 0 {
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

			// ── Phase 2: searchTracks fallback (only for tracks) ──
			if len(customResults) == 0 && searchType == "track" && extRuntime.HasMethod(ext.ID, "searchTracks") {
				tracks := trySearchTracksFlexible(ext.ID, query, limit)

				for _, t := range tracks {
					key := makeDedupKey(t, ext.ID, searchType)
					if seen[key] {
						continue
					}
					seen[key] = true
					items = append(items, mapSearchResultToItem(t, ext.ID, searchType))
					if len(items) >= limit {
						break
					}
				}
			}

			if len(items) >= limit {
				break
			}
		}

		return items, nil
	})
}
