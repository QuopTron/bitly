package runtime

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manifest"
)

// ---------------------------------------------------------------------------
// Helper: loadExtension loads an extension from the extensions/ dir on disk.
// ---------------------------------------------------------------------------

func loadExtension(t *testing.T, r *ExtensionRuntime, extID string) {
	t.Helper()
	extRoot := findExtRoot(t, extID)
	jsPath := filepath.Join(extRoot, "index.js")
	manifestPath := filepath.Join(extRoot, "manifest.json")

	if _, err := os.Stat(jsPath); err != nil {
		t.Fatalf("%s: JS not found: %s", extID, jsPath)
	}
	if _, err := os.Stat(manifestPath); err != nil {
		t.Fatalf("%s: manifest not found: %s", extID, manifestPath)
	}

	mfData, err := os.ReadFile(manifestPath)
	if err != nil {
		t.Fatalf("%s: read manifest: %v", extID, err)
	}
	mf, err := manifest.ParseManifest(mfData)
	if err != nil {
		t.Fatalf("%s: parse manifest: %v", extID, err)
	}

	if err := r.LoadExtensionWithDirs(extID, jsPath, extRoot, t.TempDir(), mf); err != nil {
		t.Fatalf("%s: load: %v", extID, err)
	}
}

func findExtRoot(t *testing.T, extID string) string {
	t.Helper()
	cwd, _ := os.Getwd()
	dir := cwd
	for i := 0; i < 20; i++ {
		testPath := filepath.Join(dir, "extensions", extID)
		if info, err := os.Stat(testPath); err == nil && info.IsDir() {
			abs, _ := filepath.Abs(testPath)
			return abs
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	t.Fatalf("could not find extensions/%s from CWD=%s", extID, cwd)
	return ""
}

// ---------------------------------------------------------------------------
// AllExtensionsSearch: test customSearch on every extension with appropriate
// filter values, verifying that each returns results for track searches.
//
// Filter mapping (matches extensionFilter in handlers/search.go):
//
//	Extension     | track filter
//	amazon        | "songs"
//	deezer        | "track"
//	qobuz-web     | "track"
//	tidal-web     | "track"
//	apple-music   | "tracks"  (default)
//	pandora       | — no customSearch
//	soundcloud    | "tracks"  (default)
//	spotify-web   | "tracks"  (default)
//	ytmusic-spotiflac | "tracks" (default)
// ---------------------------------------------------------------------------

func TestAllExtensionsCustomSearch_Tracks(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping extension network tests in short mode")
	}

	type extTestCase struct {
		id       string
		filter   string   // track filter value to use
		minCount int      // minimum expected results (0 = expect failure / skip)
		skip     bool     // skip this extension (e.g. no customSearch)
	}

	cases := []extTestCase{
		{id: "deezer",     filter: "track",   minCount: 3},
		{id: "amazon",     filter: "songs",   minCount: 0}, // Amazon needs browser-like session for search results
		{id: "qobuz-web",  filter: "track",   minCount: 3},
		{id: "tidal-web",  filter: "track",   minCount: 3},
		// Default-plural extensions (apple-music, soundcloud, spotify-web, ytmusic-spotiflac)
		// use "tracks" as the track filter
		{id: "apple-music",  filter: "tracks", minCount: 3}, // Apple Music auto-fetches token from music.apple.com
		{id: "soundcloud",   filter: "tracks", minCount: 3},
		{id: "spotify-web",  filter: "tracks", minCount: 3},
		{id: "ytmusic-spotiflac", filter: "tracks", minCount: 3},
		// Pandora: no customSearch method
		{id: "pandora", skip: true},
	}

	for _, tc := range cases {
		tc := tc
		t.Run(tc.id, func(t *testing.T) {
			if tc.skip {
				t.Skip("skipped (no customSearch)")
			}
			r := NewExtensionRuntime()
			loadExtension(t, r, tc.id)

			if !r.HasMethod(tc.id, "customSearch") {
				t.Fatal("extension does not implement customSearch")
			}

			options := map[string]interface{}{
				"limit":  5,
				"filter": tc.filter,
			}
			res, err := r.CallMethod(tc.id, "customSearch", "bad bunny", options)
			if err != nil {
				t.Fatalf("customSearch failed: %v", err)
			}
			if res == nil || res.Value == nil {
				t.Fatal("customSearch returned nil")
			}

			arr, ok := res.Value.([]interface{})
			if !ok {
				// Some extensions return a wrapper object
				if wrapper, ok := res.Value.(map[string]interface{}); ok {
					for _, key := range []string{"results", "items", "tracks"} {
						if arr2, ok2 := wrapper[key].([]interface{}); ok2 && len(arr2) > 0 {
							arr = arr2
							ok = true
							break
						}
					}
				}
				if !ok {
					t.Fatalf("expected array, got %T: %s", res.Value, truncRaw(res.RawJSON, 300))
				}
			}
			t.Logf("%s: customSearch returned %d results", tc.id, len(arr))

			if tc.minCount > 0 && len(arr) < tc.minCount {
				t.Errorf("%s: expected at least %d results, got %d", tc.id, tc.minCount, len(arr))
			}

			if len(arr) > 0 {
				if item, ok := arr[0].(map[string]interface{}); ok {
					t.Logf("  first result: id=%v name=%q", item["id"], item["name"])
					if id, _ := item["id"].(string); id == "" {
						t.Logf("  warning: first result has empty 'id'")
					}
				}
			}
		})
	}
}

// TestAllExtensionsCustomSearch_Album tests album search on extensions that support it.
func TestAllExtensionsCustomSearch_Album(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping extension network tests in short mode")
	}

	type extTestCase struct {
		id       string
		filter   string // album filter value
		skip     bool
	}

	cases := []extTestCase{
		{id: "deezer",     filter: "album"},
		{id: "amazon",     filter: "albums"},
		{id: "qobuz-web",  filter: "album"},
		{id: "tidal-web",  filter: "album"},
		{id: "apple-music",  filter: "albums"}, // Apple Music auto-fetches token
		{id: "soundcloud",   filter: "albums"},
		{id: "spotify-web",  filter: "albums"},
		{id: "ytmusic-spotiflac", filter: "albums"},
	}

	for _, tc := range cases {
		tc := tc
		t.Run(tc.id, func(t *testing.T) {
			if tc.skip {
				t.Skip("skipped")
			}
			r := NewExtensionRuntime()
			loadExtension(t, r, tc.id)
			if !r.HasMethod(tc.id, "customSearch") {
				t.Fatal("no customSearch")
			}

			options := map[string]interface{}{
				"limit":  5,
				"filter": tc.filter,
			}
			res, err := r.CallMethod(tc.id, "customSearch", "bad bunny", options)
			if err != nil {
				t.Fatalf("customSearch failed: %v", err)
			}
			if res == nil || res.Value == nil {
				t.Fatal("returned nil")
			}
			arr, ok := res.Value.([]interface{})
			if !ok {
				if wrapper, ok := res.Value.(map[string]interface{}); ok {
					for _, key := range []string{"results", "items"} {
						if a, ok2 := wrapper[key].([]interface{}); ok2 {
							arr = a
							ok = true
							break
						}
					}
				}
				if !ok {
					t.Fatalf("expected array, got %T", res.Value)
				}
			}
			t.Logf("%s: album search returned %d results", tc.id, len(arr))
			if len(arr) > 0 {
				if item, ok := arr[0].(map[string]interface{}); ok {
					t.Logf("  first: id=%v name=%q", item["id"], item["name"])
				}
			}
			if len(arr) == 0 {
				t.Logf("  NOTE: empty album results (may need API keys)")
			}
		})
	}
}

// ---------------------------------------------------------------------------
// Deezer-specific: detailed filter tests
// ---------------------------------------------------------------------------

func TestDeezerCustomSearch_AlbumFilter(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping Deezer extension test in short mode")
	}
	r := NewExtensionRuntime()
	loadExtension(t, r, "deezer")

	type testCase struct {
		name   string
		filter string
	}
	for _, tc := range []testCase{
		{"track", "track"},
		{"album", "album"},
		{"artist", "artist"},
		{"playlist", "playlist"},
	} {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			options := map[string]interface{}{
				"limit":  5,
				"filter": tc.filter,
			}
			res, err := r.CallMethod("deezer", "customSearch", "bad bunny", options)
			if err != nil {
				t.Fatalf("customSearch(%s) failed: %v", tc.name, err)
			}
			if res.Value == nil {
				t.Fatalf("customSearch(%s) returned nil", tc.name)
			}
			arr, ok := res.Value.([]interface{})
			if !ok {
				t.Fatalf("expected array, got %T: %s", res.Value, res.RawJSON)
			}
			t.Logf("customSearch(%s) returned %d results", tc.name, len(arr))
			if len(arr) == 0 {
				t.Errorf("expected at least 1 result for %s", tc.name)
			}
			if len(arr) > 0 {
				if item, ok := arr[0].(map[string]interface{}); ok {
					t.Logf("  first: id=%v name=%v", item["id"], item["name"])
				}
			}
		})
	}
}

func TestDeezerCustomSearch_NoFilter(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping Deezer extension test in short mode")
	}
	r := NewExtensionRuntime()
	loadExtension(t, r, "deezer")

	options := map[string]interface{}{"limit": 10}
	res, err := r.CallMethod("deezer", "customSearch", "bad bunny", options)
	if err != nil {
		t.Fatalf("customSearch(no filter) failed: %v", err)
	}
	if res.Value == nil {
		t.Fatal("customSearch(no filter) returned nil")
	}
	arr, ok := res.Value.([]interface{})
	if !ok {
		t.Fatalf("expected array, got %T: %s", res.Value, res.RawJSON)
	}
	t.Logf("customSearch(no filter) returned %d results", len(arr))

	typeCounts := map[string]int{}
	for _, item := range arr {
		if m, ok := item.(map[string]interface{}); ok {
			if t2, ok := m["item_type"].(string); ok {
				typeCounts[t2]++
			}
		}
	}
	for k, v := range typeCounts {
		t.Logf("  %s: %d", k, v)
	}
}

// truncRaw truncates a string for readable test output.
func truncRaw(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
}

// ---------------------------------------------------------------------------
// Parse logic tests
// ---------------------------------------------------------------------------

type SearchResult struct {
	ID           string
	Name         string
	Artists      string
	AlbumName    string
	AlbumArtist  string
	AlbumID      string
	ArtistID     string
	DurationMS   int64
	CoverURL     string
	Images       string
	ReleaseDate  string
	TrackNumber  int
	TotalTracks  int
	DiscNumber   int
	ISRC         string
	ProviderID   string
	ItemType     string
	AlbumType    string
	Owner        string
	Label        string
	Genre        string
	Composer     string
	AudioQuality string
	AudioModes   string
	TidalID      string
	QobuzID      string
	DeezerID     string
	SpotifyID    string
}

func extractString(m map[string]interface{}, keys ...string) string {
	for _, key := range keys {
		if v, ok := m[key]; ok && v != nil {
			if s, ok := v.(string); ok && s != "" {
				return s
			}
		}
	}
	return ""
}

func extractInt64(m map[string]interface{}, keys ...string) int64 {
	for _, key := range keys {
		if v, ok := m[key]; ok && v != nil {
			switch n := v.(type) {
			case float64:
				return int64(n)
			case int64:
				return n
			case int:
				return int64(n)
			}
		}
	}
	return 0
}

func parseSearchResultFromMap(item map[string]interface{}) SearchResult {
	return SearchResult{
		ID:           extractString(item, "id"),
		Name:         extractString(item, "name", "title"),
		Artists:      extractString(item, "artists", "artist", "owner"),
		AlbumName:    extractString(item, "album_name", "albumName", "album"),
		AlbumArtist:  extractString(item, "album_artist", "albumArtist"),
		AlbumID:      extractString(item, "album_id", "albumId"),
		ArtistID:     extractString(item, "artist_id", "artistId"),
		DurationMS:   extractInt64(item, "duration_ms", "durationMs", "duration"),
		CoverURL:     extractString(item, "cover_url", "coverUrl", "image", "thumbnail"),
		Images:       extractString(item, "images"),
		ReleaseDate:  extractString(item, "release_date", "releaseDate", "date"),
		TrackNumber:  int(extractInt64(item, "track_number", "trackNumber")),
		TotalTracks:  int(extractInt64(item, "total_tracks", "totalTracks", "track_count", "trackCount")),
		DiscNumber:   int(extractInt64(item, "disc_number", "discNumber")),
		ISRC:         extractString(item, "isrc"),
		ProviderID:   extractString(item, "provider_id", "providerId"),
		ItemType:     extractString(item, "item_type", "itemType", "type"),
		AlbumType:    extractString(item, "album_type", "albumType"),
		Owner:        extractString(item, "owner"),
		Label:        extractString(item, "label"),
		Genre:        extractString(item, "genre"),
		Composer:     extractString(item, "composer"),
		AudioQuality: extractString(item, "audio_quality", "audioQuality"),
		AudioModes:   extractString(item, "audio_modes", "audioModes"),
		TidalID:      extractString(item, "tidal_id", "tidalId"),
		QobuzID:      extractString(item, "qobuz_id", "qobuzId"),
		DeezerID:     extractString(item, "deezer_id", "deezerId"),
		SpotifyID:    extractString(item, "spotify_id", "spotifyId"),
	}
}

func TestParseLogic_AlbumItem(t *testing.T) {
	item := map[string]interface{}{
		"id":           "deezer:12345",
		"name":         "Test Album",
		"artists":      "Test Artist",
		"cover_url":    "https://example.com/cover.jpg",
		"provider_id":  "deezer",
		"item_type":    "album",
		"total_tracks": 12,
		"release_date": "2024-01-15",
	}
	r := parseSearchResultFromMap(item)
	if r.ID != "deezer:12345" { t.Errorf("id: got %q", r.ID) }
	if r.Name != "Test Album" { t.Errorf("name: got %q", r.Name) }
	if r.Artists != "Test Artist" { t.Errorf("artists: got %q", r.Artists) }
	if r.ItemType != "album" { t.Errorf("item_type: got %q", r.ItemType) }
	if r.CoverURL != "https://example.com/cover.jpg" { t.Errorf("cover: got %q", r.CoverURL) }
	if r.TotalTracks != 12 { t.Errorf("total_tracks: got %d", r.TotalTracks) }
}

func TestParseLogic_ArtistItem(t *testing.T) {
	item := map[string]interface{}{
		"id":          "deezer:67890",
		"name":        "Test Artist",
		"image_url":   "https://example.com/artist.jpg",
		"images":      "https://example.com/artist.jpg",
		"provider_id": "deezer",
		"item_type":   "artist",
	}
	r := parseSearchResultFromMap(item)
	if r.ID != "deezer:67890" { t.Errorf("id: got %q", r.ID) }
	if r.Name != "Test Artist" { t.Errorf("name: got %q", r.Name) }
	if r.ItemType != "artist" { t.Errorf("item_type: got %q", r.ItemType) }
}

func TestParseLogic_PlaylistItem(t *testing.T) {
	item := map[string]interface{}{
		"id":           "deezer:11111",
		"name":         "Test Playlist",
		"owner":        "Test Creator",
		"cover_url":    "https://example.com/playlist.jpg",
		"total_tracks": 50,
		"provider_id":  "deezer",
		"item_type":    "playlist",
	}
	r := parseSearchResultFromMap(item)
	if r.ID != "deezer:11111" { t.Errorf("id: got %q", r.ID) }
	if r.Name != "Test Playlist" { t.Errorf("name: got %q", r.Name) }
	if r.ItemType != "playlist" { t.Errorf("item_type: got %q", r.ItemType) }
	if r.Owner != "Test Creator" { t.Errorf("owner: got %q", r.Owner) }
	if r.TotalTracks != 50 { t.Errorf("total_tracks: got %d", r.TotalTracks) }
}

func TestParseLogic_FieldNameVariants(t *testing.T) {
	item := map[string]interface{}{
		"id":         "deezer:99999",
		"name":       "Test",
		"artist":     "Singer",
		"coverUrl":   "https://...",
		"itemType":   "track",
		"durationMs": float64(200000),
		"albumName":  "Album Title",
	}
	r := parseSearchResultFromMap(item)
	if r.Artists != "Singer" { t.Errorf("artists: got %q", r.Artists) }
	if r.CoverURL != "https://..." { t.Errorf("cover: got %q", r.CoverURL) }
	if r.ItemType != "track" { t.Errorf("item_type: got %q", r.ItemType) }
	if r.DurationMS != 200000 { t.Errorf("duration: got %d", r.DurationMS) }
	if r.AlbumName != "Album Title" { t.Errorf("album_name: got %q", r.AlbumName) }
}
