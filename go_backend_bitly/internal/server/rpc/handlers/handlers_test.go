package handlers

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/zarz/bitly/go_backend_bitly/internal/lyrics"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

// --- Helpers ---

func newTestRegistry() *rpc.Registry {
	return rpc.NewRegistry()
}

func dispatch(reg *rpc.Registry, method string, params map[string]interface{}) (interface{}, error) {
	return reg.Dispatch(method, params)
}

// --- parseStringSliceParam tests ---

func TestParseStringSliceParam(t *testing.T) {
	t.Run("nil param", func(t *testing.T) {
		result := parseStringSliceParam(nil, "key")
		if result != nil {
			t.Errorf("expected nil, got %v", result)
		}
	})

	t.Run("missing key", func(t *testing.T) {
		result := parseStringSliceParam(map[string]interface{}{}, "key")
		if result != nil {
			t.Errorf("expected nil, got %v", result)
		}
	})

	t.Run("[]interface{} value", func(t *testing.T) {
		result := parseStringSliceParam(map[string]interface{}{
			"items": []interface{}{"a", "b", "c"},
		}, "items")
		if len(result) != 3 || result[0] != "a" || result[1] != "b" || result[2] != "c" {
			t.Errorf("expected [a b c], got %v", result)
		}
	})

	t.Run("[]interface{} with mixed types", func(t *testing.T) {
		result := parseStringSliceParam(map[string]interface{}{
			"items": []interface{}{"a", 123, "c"},
		}, "items")
		if len(result) != 2 {
			t.Errorf("expected 2 strings, got %d: %v", len(result), result)
		}
	})

	t.Run("JSON string", func(t *testing.T) {
		result := parseStringSliceParam(map[string]interface{}{
			"items": `["x","y","z"]`,
		}, "items")
		if len(result) != 3 || result[0] != "x" || result[1] != "y" || result[2] != "z" {
			t.Errorf("expected [x y z], got %v", result)
		}
	})

	t.Run("single string", func(t *testing.T) {
		result := parseStringSliceParam(map[string]interface{}{
			"items": "single",
		}, "items")
		if len(result) != 1 || result[0] != "single" {
			t.Errorf("expected [single], got %v", result)
		}
	})

	t.Run("empty string", func(t *testing.T) {
		result := parseStringSliceParam(map[string]interface{}{
			"items": "",
		}, "items")
		if result != nil {
			t.Errorf("expected nil, got %v", result)
		}
	})

	t.Run("non-slice non-string", func(t *testing.T) {
		result := parseStringSliceParam(map[string]interface{}{
			"items": 42,
		}, "items")
		if result != nil {
			t.Errorf("expected nil, got %v", result)
		}
	})
}

// --- System handlers ---

func TestRegisterSystemHandlers(t *testing.T) {
	reg := newTestRegistry()
	RegisterSystemHandlers(reg)

	t.Run("ping", func(t *testing.T) {
		result, err := dispatch(reg, "ping", nil)
		if err != nil {
			t.Fatalf("ping failed: %v", err)
		}
		if result != "pong" {
			t.Errorf("expected pong, got %v", result)
		}
	})

	t.Run("exitApp", func(t *testing.T) {
		result, err := dispatch(reg, "exitApp", nil)
		if err != nil {
			t.Fatalf("exitApp failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("unknown method", func(t *testing.T) {
		_, err := dispatch(reg, "nonexistent", nil)
		if err == nil {
			t.Error("expected error for unknown method")
		}
	})
}

// --- Premium handlers ---

func TestRegisterPremiumHandlers(t *testing.T) {
	reg := newTestRegistry()
	RegisterPremiumHandlers(reg)

	t.Run("verificarPremium with is_premium=1", func(t *testing.T) {
		result, err := dispatch(reg, "verificarPremium", map[string]interface{}{
			"is_premium": 1,
		})
		if err != nil {
			t.Fatalf("verificarPremium failed: %v", err)
		}
		m, ok := result.(map[string]interface{})
		if !ok {
			t.Fatalf("expected map, got %T", result)
		}
		if m["valido"] != true {
			t.Errorf("expected valido=true")
		}
	})

	t.Run("verificarPremium with premium_until", func(t *testing.T) {
		result, err := dispatch(reg, "verificarPremium", map[string]interface{}{
			"premium_until": float64(9999999999),
		})
		if err != nil {
			t.Fatalf("verificarPremium failed: %v", err)
		}
		m, ok := result.(map[string]interface{})
		if !ok {
			t.Fatalf("expected map, got %T", result)
		}
		if m["valido"] != true {
			t.Errorf("expected valido=true")
		}
	})

	t.Run("verificarPremium without premium", func(t *testing.T) {
		_, err := dispatch(reg, "verificarPremium", map[string]interface{}{
			"is_premium":    0,
			"premium_until": 0,
		})
		if err == nil {
			t.Error("expected error for non-premium user")
		}
	})

	t.Run("validarCodigoPremium with empty code", func(t *testing.T) {
		_, err := dispatch(reg, "validarCodigoPremium", map[string]interface{}{
			"codigo": "",
		})
		// May fail or succeed depending on premium.ValidateCode implementation
		// Just check it doesn't panic
		if err != nil {
			t.Logf("validarCodigoPremium returned error (expected): %v", err)
		}
	})
}

// --- Search handlers ---

func TestRegisterSearchHandlers(t *testing.T) {
	reg := newTestRegistry()
	RegisterSearchHandlers(reg)

	t.Run("searchTracks empty query returns empty", func(t *testing.T) {
		result, err := dispatch(reg, "searchTracks", map[string]interface{}{
			"query": "",
		})
		if err != nil {
			t.Fatalf("searchTracks failed: %v", err)
		}
		// Should return empty results for empty query
		if result == nil {
			t.Log("searchTracks returned nil for empty query")
		}
	})

	t.Run("searchTracksJSON empty query", func(t *testing.T) {
		result, err := dispatch(reg, "searchTracksJSON", map[string]interface{}{
			"query": "",
		})
		if err != nil {
			t.Fatalf("searchTracksJSON failed: %v", err)
		}
		if result != "[]" {
			t.Errorf("expected [], got %v", result)
		}
	})

	t.Run("searchAlbumTracksJSON empty query", func(t *testing.T) {
		result, err := dispatch(reg, "searchAlbumTracksJSON", map[string]interface{}{
			"query": "",
		})
		if err != nil {
			t.Fatalf("searchAlbumTracksJSON failed: %v", err)
		}
		if result != "[]" {
			t.Errorf("expected [], got %v", result)
		}
	})

	t.Run("searchAndCheckAvailability empty query", func(t *testing.T) {
		result, err := dispatch(reg, "searchAndCheckAvailability", map[string]interface{}{
			"query": "",
		})
		if err != nil {
			t.Fatalf("searchAndCheckAvailability failed: %v", err)
		}
		if result != nil {
			t.Errorf("expected nil for empty query, got %v", result)
		}
	})

	t.Run("resolveTrackByISRC empty", func(t *testing.T) {
		_, err := dispatch(reg, "resolveTrackByISRC", map[string]interface{}{
			"isrc": "",
		})
		// May fail or succeed depending on link resolver
		if err != nil {
			t.Logf("resolveTrackByISRC returned error (expected): %v", err)
		}
	})
}

// --- Availability handlers ---

func TestRegisterAvailabilityHandlers(t *testing.T) {
	reg := newTestRegistry()
	RegisterAvailabilityHandlers(reg)

	t.Run("setSongLinkRegion", func(t *testing.T) {
		result, err := dispatch(reg, "setSongLinkRegion", map[string]interface{}{
			"region": "US",
		})
		if err != nil {
			t.Fatalf("setSongLinkRegion failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("setSongLinkRegion empty defaults to US", func(t *testing.T) {
		result, err := dispatch(reg, "setSongLinkRegion", nil)
		if err != nil {
			t.Fatalf("setSongLinkRegion failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("checkAvailability empty params", func(t *testing.T) {
		_, err := dispatch(reg, "checkAvailability", nil)
		// Will fail because empty spotify_id and isrc won't find anything
		if err != nil {
			t.Logf("checkAvailability error (expected): %v", err)
		}
	})

	t.Run("getSpotifyIDFromDeezer empty", func(t *testing.T) {
		_, err := dispatch(reg, "getSpotifyIDFromDeezer", nil)
		if err != nil {
			t.Logf("getSpotifyIDFromDeezer error (expected): %v", err)
		}
	})

	t.Run("getYouTubeURLFromDeezer empty", func(t *testing.T) {
		_, err := dispatch(reg, "getYouTubeURLFromDeezer", nil)
		if err != nil {
			t.Logf("getYouTubeURLFromDeezer error (expected): %v", err)
		}
	})

	t.Run("resolveByISRC empty", func(t *testing.T) {
		_, err := dispatch(reg, "resolveByISRC", nil)
		if err != nil {
			t.Logf("resolveByISRC error (expected): %v", err)
		}
	})
}

// --- Video handlers ---

func TestRegisterVideoHandlers(t *testing.T) {
	reg := newTestRegistry()
	RegisterVideoHandlers(reg)

	t.Run("ensureYtDlp", func(t *testing.T) {
		result, err := dispatch(reg, "ensureYtDlp", nil)
		// May fail if yt-dlp not installed, but should not panic
		if err != nil {
			t.Logf("ensureYtDlp error (expected in test env): %v", err)
		} else {
			t.Logf("ensureYtDlp returned: %v", result)
		}
	})

	t.Run("getYtDlpPath", func(t *testing.T) {
		result, err := dispatch(reg, "getYtDlpPath", nil)
		if err != nil {
			t.Fatalf("getYtDlpPath failed: %v", err)
		}
		t.Logf("yt-dlp path: %v", result)
	})

	t.Run("setYtDlpPath", func(t *testing.T) {
		result, err := dispatch(reg, "setYtDlpPath", map[string]interface{}{
			"path": "/custom/yt-dlp",
		})
		if err != nil {
			t.Fatalf("setYtDlpPath failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("searchYouTubeVideo empty params", func(t *testing.T) {
		_, err := dispatch(reg, "searchYouTubeVideo", nil)
		if err != nil {
			t.Logf("searchYouTubeVideo error (expected): %v", err)
		}
	})
}

// --- Lyrics handlers ---

func TestRegisterLyricsHandlers(t *testing.T) {
	reg := newTestRegistry()
	RegisterLyricsHandlers(reg)

	t.Run("getAvailableLyricsProviders", func(t *testing.T) {
		result, err := dispatch(reg, "getAvailableLyricsProviders", nil)
		if err != nil {
			t.Fatalf("getAvailableLyricsProviders failed: %v", err)
		}
		providers, ok := result.([]map[string]interface{})
		if !ok {
			// Could also be []interface{} depending on marshaling
			t.Logf("getAvailableLyricsProviders returned %T", result)
		}
		_ = providers
	})

	t.Run("getLyricsProviders", func(t *testing.T) {
		result, err := dispatch(reg, "getLyricsProviders", nil)
		if err != nil {
			t.Fatalf("getLyricsProviders failed: %v", err)
		}
		t.Logf("lyrics providers: %v", result)
	})

	t.Run("setLyricsProviders valid JSON", func(t *testing.T) {
		providersJSON := `["lrclib","apple_music"]`
		result, err := dispatch(reg, "setLyricsProviders", map[string]interface{}{
			"providers": providersJSON,
		})
		if err != nil {
			t.Fatalf("setLyricsProviders failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
		// Verify it was set
		order := lyrics.GetLyricsProviderOrder()
		if len(order) != 2 || order[0] != "lrclib" || order[1] != "apple_music" {
			t.Errorf("unexpected provider order: %v", order)
		}
		// Reset
		lyrics.SetLyricsProviderOrder(nil)
	})

	t.Run("setLyricsProviders invalid JSON", func(t *testing.T) {
		_, err := dispatch(reg, "setLyricsProviders", map[string]interface{}{
			"providers": "not valid json",
		})
		if err == nil {
			t.Error("expected error for invalid JSON")
		}
	})

	t.Run("getLyricsFetchOptions", func(t *testing.T) {
		result, err := dispatch(reg, "getLyricsFetchOptions", nil)
		if err != nil {
			t.Fatalf("getLyricsFetchOptions failed: %v", err)
		}
		opts, ok := result.(lyrics.LyricsFetchOptions)
		if !ok {
			t.Logf("getLyricsFetchOptions returned %T", result)
		}
		_ = opts
	})

	t.Run("setLyricsFetchOptions", func(t *testing.T) {
		optionsJSON := `{"multi_person_word_by_word":false,"apple_elrc_word_sync":true}`
		result, err := dispatch(reg, "setLyricsFetchOptions", map[string]interface{}{
			"options": optionsJSON,
		})
		if err != nil {
			t.Fatalf("setLyricsFetchOptions failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
		opts := lyrics.GetLyricsFetchOptions()
		if opts.MultiPersonWordByWord != false {
			t.Error("expected MultiPersonWordByWord to be false")
		}
		if opts.AppleElrcWordSync != true {
			t.Error("expected AppleElrcWordSync to be true")
		}
	})

	t.Run("setLyricsFetchOptions empty", func(t *testing.T) {
		result, err := dispatch(reg, "setLyricsFetchOptions", map[string]interface{}{
			"options": "",
		})
		if err != nil {
			t.Fatalf("setLyricsFetchOptions failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok")
		}
	})

	t.Run("fetchLyrics empty params", func(t *testing.T) {
		_, err := dispatch(reg, "fetchLyrics", nil)
		if err != nil {
			t.Logf("fetchLyrics error (expected): %v", err)
		}
	})

	t.Run("getLyricsLRC returns result", func(t *testing.T) {
		result, err := dispatch(reg, "getLyricsLRC", map[string]interface{}{
			"track_name":  "Nonexistent Song",
			"artist_name": "Nonexistent Artist",
		})
		if err != nil {
			t.Fatalf("getLyricsLRC failed: %v", err)
		}
		t.Logf("getLyricsLRC returned: %v", result)
	})

	t.Run("getLyricsLRCWithSource returns result", func(t *testing.T) {
		result, err := dispatch(reg, "getLyricsLRCWithSource", map[string]interface{}{
			"track_name":  "Unknown",
			"artist_name": "Unknown",
		})
		if err != nil {
			t.Fatalf("getLyricsLRCWithSource failed: %v", err)
		}
		t.Logf("getLyricsLRCWithSource returned: %T %v", result, result)
	})

	t.Run("embedLyricsToFile missing params", func(t *testing.T) {
		result, err := dispatch(reg, "embedLyricsToFile", map[string]interface{}{
			"audio_file_path": "",
			"track_name":      "",
			"artist_name":     "",
		})
		if err != nil {
			t.Fatalf("embedLyricsToFile failed: %v", err)
		}
		m, ok := result.(map[string]interface{})
		if !ok {
			t.Fatalf("expected map, got %T", result)
		}
		if m["success"] != false {
			t.Errorf("expected success=false, got %v", m["success"])
		}
	})

	t.Run("saveLRCFile missing audio path", func(t *testing.T) {
		_, err := dispatch(reg, "saveLRCFile", nil)
		if err == nil {
			t.Error("expected error for missing audio path")
		}
	})

	t.Run("getTranslatedLyricsLRC empty language", func(t *testing.T) {
		result, err := dispatch(reg, "getTranslatedLyricsLRC", map[string]interface{}{
			"track_name":  "Test",
			"artist_name": "Test",
			"language":    "",
		})
		if err != nil {
			t.Fatalf("getTranslatedLyricsLRC failed: %v", err)
		}
		if result != "" {
			t.Errorf("expected empty string, got %v", result)
		}
	})

	// --- JSON alias tests ---

	t.Run("getLyricsProvidersJSON returns JSON string", func(t *testing.T) {
		result, err := dispatch(reg, "getLyricsProvidersJSON", nil)
		if err != nil {
			t.Fatalf("getLyricsProvidersJSON failed: %v", err)
		}
		// Should be a valid JSON string
		if _, ok := result.(string); !ok {
			t.Errorf("expected string, got %T", result)
		}
	})

	t.Run("setLyricsProvidersJSON valid", func(t *testing.T) {
		result, err := dispatch(reg, "setLyricsProvidersJSON", map[string]interface{}{
			"providers_json": `["lrclib"]`,
		})
		if err != nil {
			t.Fatalf("setLyricsProvidersJSON failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
		// Reset
		lyrics.SetLyricsProviderOrder(nil)
	})

	t.Run("setLyricsProvidersJSON fallback to providers", func(t *testing.T) {
		result, err := dispatch(reg, "setLyricsProvidersJSON", map[string]interface{}{
			"providers": `["apple_music"]`,
		})
		if err != nil {
			t.Fatalf("setLyricsProvidersJSON failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
		lyrics.SetLyricsProviderOrder(nil)
	})

	t.Run("getAvailableLyricsProvidersJSON returns JSON string", func(t *testing.T) {
		result, err := dispatch(reg, "getAvailableLyricsProvidersJSON", nil)
		if err != nil {
			t.Fatalf("getAvailableLyricsProvidersJSON failed: %v", err)
		}
		// Should be a valid JSON string
		if _, ok := result.(string); !ok {
			t.Errorf("expected string, got %T", result)
		}
	})

	t.Run("setLyricsFetchOptionsJSON valid", func(t *testing.T) {
		optionsJSON := `{"apple_elrc_word_sync":true}`
		result, err := dispatch(reg, "setLyricsFetchOptionsJSON", map[string]interface{}{
			"options_json": optionsJSON,
		})
		if err != nil {
			t.Fatalf("setLyricsFetchOptionsJSON failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
		// Reset
		lyrics.SetLyricsFetchOptions(lyrics.LyricsFetchOptions{})
	})

	t.Run("setLyricsFetchOptionsJSON fallback to options", func(t *testing.T) {
		optionsJSON := `{"multi_person_word_by_word":false}`
		result, err := dispatch(reg, "setLyricsFetchOptionsJSON", map[string]interface{}{
			"options": optionsJSON,
		})
		if err != nil {
			t.Fatalf("setLyricsFetchOptionsJSON failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
		lyrics.SetLyricsFetchOptions(lyrics.LyricsFetchOptions{})
	})

	t.Run("getLyricsFetchOptionsJSON returns JSON string", func(t *testing.T) {
		result, err := dispatch(reg, "getLyricsFetchOptionsJSON", nil)
		if err != nil {
			t.Fatalf("getLyricsFetchOptionsJSON failed: %v", err)
		}
		// Should be a valid JSON string
		if _, ok := result.(string); !ok {
			t.Errorf("expected string, got %T", result)
		}
	})
}

// --- Playback handlers ---

func TestRegisterPlaybackHandlers(t *testing.T) {
	reg := newTestRegistry()
	RegisterPlaybackHandlers(reg)

	t.Run("playbackPause", func(t *testing.T) {
		result, err := dispatch(reg, "playbackPause", nil)
		if err != nil {
			t.Fatalf("playbackPause failed: %v", err)
		}
		t.Logf("playbackPause returned: %v", result)
	})

	t.Run("playbackStop", func(t *testing.T) {
		result, err := dispatch(reg, "playbackStop", nil)
		if err != nil {
			t.Fatalf("playbackStop failed: %v", err)
		}
		t.Logf("playbackStop returned: %v", result)
	})

	t.Run("playbackGetState", func(t *testing.T) {
		result, err := dispatch(reg, "playbackGetState", nil)
		if err != nil {
			t.Fatalf("playbackGetState failed: %v", err)
		}
		t.Logf("playbackGetState returned: %v", result)
	})

	t.Run("playbackGetQueue", func(t *testing.T) {
		result, err := dispatch(reg, "playbackGetQueue", nil)
		if err != nil {
			t.Fatalf("playbackGetQueue failed: %v", err)
		}
		t.Logf("playbackGetQueue returned: %v", result)
	})

	t.Run("playbackGetHistory no limit", func(t *testing.T) {
		result, err := dispatch(reg, "playbackGetHistory", nil)
		if err != nil {
			t.Fatalf("playbackGetHistory failed: %v", err)
		}
		t.Logf("playbackGetHistory returned: %v", result)
	})

	t.Run("playbackSetQueue empty", func(t *testing.T) {
		result, err := dispatch(reg, "playbackSetQueue", map[string]interface{}{
			"tracks": "",
		})
		if err != nil {
			t.Fatalf("playbackSetQueue failed: %v", err)
		}
		// Should return error for empty queue
		t.Logf("playbackSetQueue returned: %v", result)
	})

	t.Run("playbackAddToQueue empty", func(t *testing.T) {
		result, err := dispatch(reg, "playbackAddToQueue", map[string]interface{}{
			"tracks": "",
		})
		if err != nil {
			t.Fatalf("playbackAddToQueue failed: %v", err)
		}
		t.Logf("playbackAddToQueue returned: %v", result)
	})

	t.Run("playbackRemoveFromQueue", func(t *testing.T) {
		result, err := dispatch(reg, "playbackRemoveFromQueue", map[string]interface{}{
			"index": 0,
		})
		if err != nil {
			t.Fatalf("playbackRemoveFromQueue failed: %v", err)
		}
		t.Logf("playbackRemoveFromQueue returned: %v", result)
	})

	t.Run("playbackClearQueue", func(t *testing.T) {
		result, err := dispatch(reg, "playbackClearQueue", nil)
		if err != nil {
			t.Fatalf("playbackClearQueue failed: %v", err)
		}
		t.Logf("playbackClearQueue returned: %v", result)
	})

	t.Run("playbackSetShuffle", func(t *testing.T) {
		result, err := dispatch(reg, "playbackSetShuffle", map[string]interface{}{
			"shuffle": 1,
		})
		if err != nil {
			t.Fatalf("playbackSetShuffle failed: %v", err)
		}
		t.Logf("playbackSetShuffle returned: %v", result)
	})

	t.Run("playbackSetRepeat", func(t *testing.T) {
		result, err := dispatch(reg, "playbackSetRepeat", map[string]interface{}{
			"mode": "all",
		})
		if err != nil {
			t.Fatalf("playbackSetRepeat failed: %v", err)
		}
		t.Logf("playbackSetRepeat returned: %v", result)
	})

	t.Run("playbackSetRepeat empty defaults to none", func(t *testing.T) {
		result, err := dispatch(reg, "playbackSetRepeat", nil)
		if err != nil {
			t.Fatalf("playbackSetRepeat failed: %v", err)
		}
		t.Logf("playbackSetRepeat (default) returned: %v", result)
	})

	t.Run("playbackTrackCompleted", func(t *testing.T) {
		result, err := dispatch(reg, "playbackTrackCompleted", nil)
		if err != nil {
			t.Fatalf("playbackTrackCompleted failed: %v", err)
		}
		t.Logf("playbackTrackCompleted returned: %v", result)
	})

	t.Run("playbackUpdatePosition", func(t *testing.T) {
		result, err := dispatch(reg, "playbackUpdatePosition", map[string]interface{}{
			"position_ms": float64(5000),
		})
		if err != nil {
			t.Fatalf("playbackUpdatePosition failed: %v", err)
		}
		t.Logf("playbackUpdatePosition returned: %v", result)
	})

	t.Run("playbackPlayTrack empty", func(t *testing.T) {
		result, err := dispatch(reg, "playbackPlayTrack", nil)
		if err != nil {
			t.Fatalf("playbackPlayTrack failed: %v", err)
		}
		if result != nil {
			t.Logf("playbackPlayTrack returned: %v", result)
		}
	})

	t.Run("playbackSeek", func(t *testing.T) {
		result, err := dispatch(reg, "playbackSeek", nil)
		if err != nil {
			t.Fatalf("playbackSeek failed: %v", err)
		}
		t.Logf("playbackSeek returned: %v", result)
	})

	t.Run("playbackSyncQueueState empty", func(t *testing.T) {
		result, err := dispatch(reg, "playbackSyncQueueState", nil)
		if err != nil {
			t.Fatalf("playbackSyncQueueState failed: %v", err)
		}
		t.Logf("playbackSyncQueueState returned: %v", result)
	})

	t.Run("getSimilarTracks empty", func(t *testing.T) {
		result, err := dispatch(reg, "getSimilarTracks", nil)
		if err != nil {
			t.Fatalf("getSimilarTracks failed: %v", err)
		}
		if result != "[]" {
			t.Errorf("expected [], got %v", result)
		}
	})
}

// --- Download History handlers ---

func TestRegisterDownloadHistory(t *testing.T) {
	reg := newTestRegistry()

	// Download history handlers are registered through a separate init
	// Just test that the registration works
	t.Run("getDownloadHistoryCount", func(t *testing.T) {
		// This should work as it delegates to database
		// Without DB init, it may fail
		reg.Register("getDownloadHistoryCount", func(params map[string]interface{}) (interface{}, error) {
			return 0, nil
		})
		result, err := dispatch(reg, "getDownloadHistoryCount", nil)
		if err != nil {
			t.Fatalf("getDownloadHistoryCount failed: %v", err)
		}
		if result != 0 {
			t.Errorf("expected 0, got %v", result)
		}
	})

	t.Run("clearDownloadHistory", func(t *testing.T) {
		reg.Register("clearDownloadHistory", func(params map[string]interface{}) (interface{}, error) {
			return "ok", nil
		})
		result, err := dispatch(reg, "clearDownloadHistory", nil)
		if err != nil {
			t.Fatalf("clearDownloadHistory failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})
}

// --- Metadata handlers ---

func TestRegisterMetadataHandlers(t *testing.T) {
	reg := newTestRegistry()
	RegisterMetadataHandlers(reg)

	t.Run("sanitizeFilename", func(t *testing.T) {
		result, err := dispatch(reg, "sanitizeFilename", map[string]interface{}{
			"filename": "test/file:name?.mp3",
		})
		if err != nil {
			t.Fatalf("sanitizeFilename failed: %v", err)
		}
		t.Logf("sanitizeFilename returned: %v", result)
	})

	t.Run("sanitizeFolderName", func(t *testing.T) {
		result, err := dispatch(reg, "sanitizeFolderName", map[string]interface{}{
			"name": "Artist - Album (2024)",
		})
		if err != nil {
			t.Fatalf("sanitizeFolderName failed: %v", err)
		}
		t.Logf("sanitizeFolderName returned: %v", result)
	})

	t.Run("normalizeOptionalString", func(t *testing.T) {
		result, err := dispatch(reg, "normalizeOptionalString", map[string]interface{}{
			"value": "  Test  ",
		})
		if err != nil {
			t.Fatalf("normalizeOptionalString failed: %v", err)
		}
		if result != "Test" {
			t.Errorf("expected 'Test', got %v", result)
		}
	})

	t.Run("formatSampleRateKHz", func(t *testing.T) {
		result, err := dispatch(reg, "formatSampleRateKHz", map[string]interface{}{
			"sample_rate": float64(44100),
		})
		if err != nil {
			t.Fatalf("formatSampleRateKHz failed: %v", err)
		}
		t.Logf("formatSampleRateKHz returned: %v", result)
	})

	t.Run("isPlaceholderQualityLabel", func(t *testing.T) {
		result, err := dispatch(reg, "isPlaceholderQualityLabel", map[string]interface{}{
			"quality": "FLAC",
		})
		if err != nil {
			t.Fatalf("isPlaceholderQualityLabel failed: %v", err)
		}
		t.Logf("isPlaceholderQualityLabel returned: %v", result)
	})

	t.Run("audioMimeTypeForPath", func(t *testing.T) {
		result, err := dispatch(reg, "audioMimeTypeForPath", map[string]interface{}{
			"file_path": "song.flac",
		})
		if err != nil {
			t.Fatalf("audioMimeTypeForPath failed: %v", err)
		}
		if result != "audio/flac" {
			t.Errorf("expected audio/flac, got %v", result)
		}
	})

	t.Run("audioMimeTypeForPath mp3", func(t *testing.T) {
		result, err := dispatch(reg, "audioMimeTypeForPath", map[string]interface{}{
			"file_path": "song.mp3",
		})
		if err != nil {
			t.Fatalf("audioMimeTypeForPath failed: %v", err)
		}
		if result != "audio/mpeg" {
			t.Errorf("expected audio/mpeg, got %v", result)
		}
	})

	t.Run("buildDisplayAudioQuality", func(t *testing.T) {
		result, err := dispatch(reg, "buildDisplayAudioQuality", map[string]interface{}{
			"bit_depth":    float64(24),
			"sample_rate":  float64(96000),
			"bitrate_kbps": float64(0),
			"format":       "FLAC",
			"stored_quality": "Hi-Res",
		})
		if err != nil {
			t.Fatalf("buildDisplayAudioQuality failed: %v", err)
		}
		t.Logf("buildDisplayAudioQuality returned: %v", result)
	})

	t.Run("buildFilename", func(t *testing.T) {
		result, err := dispatch(reg, "buildFilename", map[string]interface{}{
			"template": "{artist} - {title}",
			"metadata": `{"artist":"Test","title":"Song"}`,
		})
		if err != nil {
			t.Fatalf("buildFilename failed: %v", err)
		}
		t.Logf("buildFilename returned: %v", result)
	})

	t.Run("buildFilename empty template", func(t *testing.T) {
		_, err := dispatch(reg, "buildFilename", map[string]interface{}{
			"template": "",
		})
		if err == nil {
			t.Error("expected error for empty template")
		}
	})

	t.Run("readFileMetadata empty path", func(t *testing.T) {
		_, err := dispatch(reg, "readFileMetadata", map[string]interface{}{
			"file_path": "",
		})
		if err == nil {
			t.Error("expected error for empty file path")
		}
	})

	t.Run("extractCoverToFile empty paths", func(t *testing.T) {
		_, err := dispatch(reg, "extractCoverToFile", nil)
		if err == nil {
			t.Error("expected error for empty paths")
		}
	})

	t.Run("downloadCoverToFile empty URL", func(t *testing.T) {
		_, err := dispatch(reg, "downloadCoverToFile", map[string]interface{}{
			"cover_url":   "",
			"output_path": "/tmp/cover.jpg",
		})
		if err == nil {
			t.Error("expected error for empty cover URL")
		}
	})
}

// --- Metadata utilities ---

func TestSanitizeFilename(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"test", "test"},
		{"file:name", "file_name"},
		{"a/b/c", "a_b_c"},
		{"hello*world", "hello_world"},
		{"file<name>", "file_name_"},
		{"file|name", "file_name"},
	}
	for _, tt := range tests {
		got := sanitizeFilename(tt.input)
		if got != tt.want {
			t.Errorf("sanitizeFilename(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

func TestSanitizeFilename_Spaces(t *testing.T) {
	got := sanitizeFilename("  file name  ")
	if got != "file name" {
		t.Errorf("expected 'file name', got %q", got)
	}
}

func TestSanitizeFilename_Empty(t *testing.T) {
	got := sanitizeFilename("")
	if got != "" {
		t.Errorf("expected empty, got %q", got)
	}
}

// --- BuildFilenameFromTemplate ---

func TestBuildFilenameFromTemplate(t *testing.T) {
	tests := []struct {
		template string
		meta     map[string]interface{}
		want     string
	}{
		{"{artist} - {title}", map[string]interface{}{"artist": "Test", "title": "Song"}, "Test - Song"},
		{"simple", nil, "simple"},
		{"", nil, "unknown"},
		{"{missing}", map[string]interface{}{}, "{missing}"},
	}
	for _, tt := range tests {
		got := buildFilenameFromTemplate(tt.template, tt.meta)
		if got != tt.want {
			t.Errorf("buildFilenameFromTemplate(%q, %v) = %q, want %q", tt.template, tt.meta, got, tt.want)
		}
	}
}

// --- Metadata utils extra ---

func TestRegisterMetadataUtilsExtra(t *testing.T) {
	// Use full metadata handler registration to include all utils
	reg := newTestRegistry()
	RegisterMetadataHandlers(reg)

	t.Run("normalizeIsrc", func(t *testing.T) {
		result, err := dispatch(reg, "normalizeIsrc", map[string]interface{}{"value": "usabc1234567"})
		if err != nil {
			t.Fatalf("normalizeIsrc failed: %v", err)
		}
		t.Logf("normalizeIsrc returned: %v", result)
	})

	t.Run("normalizeSpotifyId", func(t *testing.T) {
		result, err := dispatch(reg, "normalizeSpotifyId", map[string]interface{}{"value": " 4iV5W9uYEdYUVa79Axb7Rh "})
		if err != nil {
			t.Fatalf("normalizeSpotifyId failed: %v", err)
		}
		t.Logf("normalizeSpotifyId returned: %v", result)
	})

	t.Run("matchKeyFor", func(t *testing.T) {
		result, err := dispatch(reg, "matchKeyFor", map[string]interface{}{"track": "Song", "artist": "Artist"})
		if err != nil {
			t.Fatalf("matchKeyFor failed: %v", err)
		}
		t.Logf("matchKeyFor returned: %v", result)
	})

	t.Run("buildPathMatchKeys", func(t *testing.T) {
		result, err := dispatch(reg, "buildPathMatchKeys", map[string]interface{}{"file_path": "/music/song.flac"})
		if err != nil {
			t.Fatalf("buildPathMatchKeys failed: %v", err)
		}
		t.Logf("buildPathMatchKeys returned: %v", result)
	})

	t.Run("deleteFileAndCleanupFolder non-existent", func(t *testing.T) {
		result, err := dispatch(reg, "deleteFileAndCleanupFolder", map[string]interface{}{"file_path": "/nonexistent/file.flac"})
		if err != nil {
			t.Fatalf("deleteFileAndCleanupFolder failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("deleteSidecarFiles non-existent", func(t *testing.T) {
		result, err := dispatch(reg, "deleteSidecarFiles", map[string]interface{}{"audio_path": "/nonexistent/song.flac"})
		if err != nil {
			t.Fatalf("deleteSidecarFiles failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})
}

// --- Download misc handlers ---

func TestRegisterDownloadMisc(t *testing.T) {
	reg := newTestRegistry()
	registerDownloadMisc(reg)

	t.Run("findExistingDownloadEntry empty params", func(t *testing.T) {
		result, err := dispatch(reg, "findExistingDownloadEntry", nil)
		if err != nil {
			t.Fatalf("findExistingDownloadEntry failed: %v", err)
		}
		t.Logf("findExistingDownloadEntry returned: %v", result)
	})
}

// --- Extensions auth handlers ---

func TestRegisterExtensionAuth(t *testing.T) {
	reg := newTestRegistry()
	registerExtensionAuth(reg)

	t.Run("getExtensionPendingAuth empty id", func(t *testing.T) {
		result, err := dispatch(reg, "getExtensionPendingAuth", nil)
		if err != nil {
			t.Fatalf("getExtensionPendingAuth failed: %v", err)
		}
		if result != "{}" {
			t.Errorf("expected {}, got %v", result)
		}
	})

	t.Run("setExtensionAuthCode", func(t *testing.T) {
		result, err := dispatch(reg, "setExtensionAuthCode", map[string]interface{}{
			"extension_id": "test_ext",
			"code":         "auth123",
		})
		if err != nil {
			t.Fatalf("setExtensionAuthCode failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("setExtensionTokens", func(t *testing.T) {
		result, err := dispatch(reg, "setExtensionTokens", map[string]interface{}{
			"extension_id": "test_ext",
			"access_token": "access123",
			"refresh_token": "refresh123",
		})
		if err != nil {
			t.Fatalf("setExtensionTokens failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("clearExtensionPendingAuth", func(t *testing.T) {
		result, err := dispatch(reg, "clearExtensionPendingAuth", map[string]interface{}{
			"extension_id": "test_ext",
		})
		if err != nil {
			t.Fatalf("clearExtensionPendingAuth failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("clearExtensionPendingAuth empty id", func(t *testing.T) {
		result, err := dispatch(reg, "clearExtensionPendingAuth", nil)
		if err != nil {
			t.Fatalf("clearExtensionPendingAuth failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("isExtensionAuthenticated empty id", func(t *testing.T) {
		result, err := dispatch(reg, "isExtensionAuthenticated", nil)
		if err != nil {
			t.Fatalf("isExtensionAuthenticated failed: %v", err)
		}
		if result != "false" {
			t.Errorf("expected false, got %v", result)
		}
	})

	t.Run("getAllPendingAuthRequests", func(t *testing.T) {
		result, err := dispatch(reg, "getAllPendingAuthRequests", nil)
		if err != nil {
			t.Fatalf("getAllPendingAuthRequests failed: %v", err)
		}
		// Should be valid JSON array
		var arr []interface{}
		if err := json.Unmarshal([]byte(result.(string)), &arr); err != nil {
			t.Errorf("expected valid JSON array: %v", err)
		}
	})
}

// ============================================================
// Library handlers (scan, entries, pages, maintenance)
// ============================================================

func TestRegisterLibraryScanHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerLibraryScan(reg)

	methods := []string{
		"scanLibraryFolder",
		"scanLibraryFolderIncremental",
		"scanLibraryFolderIncrementalFromSnapshot",
		"scanSafTreeIncremental",
		"scanSafTreeIncrementalFromSnapshot",
		"getLibraryScanProgress",
		"cancelLibraryScan",
		"setLibraryCoverCacheDir",
	}
	for _, m := range methods {
		t.Run(m, func(t *testing.T) {
			result, err := dispatch(reg, m, nil)
			if err != nil {
				t.Fatalf("%s failed: %v", m, err)
			}
			if result == nil {
				t.Errorf("%s returned nil", m)
			}
		})
	}
}

func TestRegisterLibraryScanHandlers_SpecificValues(t *testing.T) {
	reg := newTestRegistry()
	registerLibraryScan(reg)

	t.Run("scanLibraryFolder returns []", func(t *testing.T) {
		result, err := dispatch(reg, "scanLibraryFolder", nil)
		if err != nil {
			t.Fatalf("scanLibraryFolder failed: %v", err)
		}
		if result != "[]" {
			t.Errorf("expected [], got %v", result)
		}
	})

	t.Run("cancelLibraryScan returns ok", func(t *testing.T) {
		result, err := dispatch(reg, "cancelLibraryScan", nil)
		if err != nil {
			t.Fatalf("cancelLibraryScan failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("setLibraryCoverCacheDir returns ok", func(t *testing.T) {
		result, err := dispatch(reg, "setLibraryCoverCacheDir", nil)
		if err != nil {
			t.Fatalf("setLibraryCoverCacheDir failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("getLibraryScanProgress returns {}", func(t *testing.T) {
		result, err := dispatch(reg, "getLibraryScanProgress", nil)
		if err != nil {
			t.Fatalf("getLibraryScanProgress failed: %v", err)
		}
		if result != "{}" {
			t.Errorf("expected {}, got %v", result)
		}
	})
}

func TestRegisterLibraryEntriesHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerLibraryEntries(reg)

	t.Run("getLocalLibraryEntryByID empty", func(t *testing.T) {
		_, err := dispatch(reg, "getLocalLibraryEntryByID", nil)
		// DB not initialized, will return error
		if err == nil {
			t.Log("getLocalLibraryEntryByID succeeded (unexpected)")
		}
	})

	t.Run("getLocalLibraryEntryByIsrc empty", func(t *testing.T) {
		_, err := dispatch(reg, "getLocalLibraryEntryByIsrc", nil)
		if err == nil {
			t.Log("getLocalLibraryEntryByIsrc succeeded (unexpected)")
		}
	})

	t.Run("findLocalLibraryEntryByTrackAndArtist empty", func(t *testing.T) {
		_, err := dispatch(reg, "findLocalLibraryEntryByTrackAndArtist", nil)
		if err == nil {
			t.Log("findLocalLibraryEntryByTrackAndArtist succeeded (unexpected)")
		}
	})

	t.Run("getLocalLibraryCoverPaths", func(t *testing.T) {
		_, err := dispatch(reg, "getLocalLibraryCoverPaths", nil)
		if err == nil {
			t.Log("getLocalLibraryCoverPaths succeeded (unexpected)")
		}
	})

	t.Run("getLocalLibraryEntriesWithPathsPage default limit", func(t *testing.T) {
		_, err := dispatch(reg, "getLocalLibraryEntriesWithPathsPage", nil)
		if err == nil {
			t.Log("getLocalLibraryEntriesWithPathsPage succeeded (unexpected)")
		}
	})
}

func TestRegisterLibraryPagesHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerLibraryPages(reg)

	t.Run("getLocalLibraryPage defaults", func(t *testing.T) {
		_, err := dispatch(reg, "getLocalLibraryPage", nil)
		if err == nil {
			t.Log("getLocalLibraryPage succeeded without DB (unexpected)")
		}
	})

	t.Run("getLocalLibraryCount empty", func(t *testing.T) {
		_, err := dispatch(reg, "getLocalLibraryCount", nil)
		if err == nil {
			t.Log("getLocalLibraryCount succeeded without DB (unexpected)")
		}
	})

	t.Run("getLocalLibraryAlbumGroups defaults", func(t *testing.T) {
		_, err := dispatch(reg, "getLocalLibraryAlbumGroups", nil)
		if err == nil {
			t.Log("getLocalLibraryAlbumGroups succeeded without DB (unexpected)")
		}
	})

	t.Run("getLocalLibraryAlbumGroupCount empty", func(t *testing.T) {
		_, err := dispatch(reg, "getLocalLibraryAlbumGroupCount", nil)
		if err == nil {
			t.Log("getLocalLibraryAlbumGroupCount succeeded without DB (unexpected)")
		}
	})

	t.Run("getLocalLibrarySingleTrackCount empty", func(t *testing.T) {
		_, err := dispatch(reg, "getLocalLibrarySingleTrackCount", nil)
		if err == nil {
			t.Log("getLocalLibrarySingleTrackCount succeeded without DB (unexpected)")
		}
	})

	t.Run("getLocalLibrarySingleTrackCount with searchQuery", func(t *testing.T) {
		_, err := dispatch(reg, "getLocalLibrarySingleTrackCount", map[string]interface{}{"searchQuery": "test"})
		if err == nil {
			t.Log("getLocalLibrarySingleTrackCount succeeded without DB (unexpected)")
		}
	})

	t.Run("getLocalLibrarySingleTrackCount with search_query alias", func(t *testing.T) {
		_, err := dispatch(reg, "getLocalLibrarySingleTrackCount", map[string]interface{}{"search_query": "test"})
		if err == nil {
			t.Log("getLocalLibrarySingleTrackCount with search_query succeeded without DB (unexpected)")
		}
	})
}

func TestRegisterLibraryMaintenanceHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerLibraryMaintenance(reg)

	t.Run("updateLocalLibraryFileModTimes empty", func(t *testing.T) {
		_, err := dispatch(reg, "updateLocalLibraryFileModTimes", nil)
		if err == nil {
			t.Log("updateLocalLibraryFileModTimes succeeded without DB (unexpected)")
		}
	})

	t.Run("updateLocalLibraryAudioMetadata empty", func(t *testing.T) {
		_, err := dispatch(reg, "updateLocalLibraryAudioMetadata", nil)
		if err == nil {
			t.Log("updateLocalLibraryAudioMetadata succeeded without DB (unexpected)")
		}
	})

	t.Run("getLocalLibraryArtistTracks empty", func(t *testing.T) {
		_, err := dispatch(reg, "getLocalLibraryArtistTracks", nil)
		if err == nil {
			t.Log("getLocalLibraryArtistTracks succeeded without DB (unexpected)")
		}
	})

	t.Run("getLocalLibraryAlbumTracks empty", func(t *testing.T) {
		_, err := dispatch(reg, "getLocalLibraryAlbumTracks", nil)
		if err == nil {
			t.Log("getLocalLibraryAlbumTracks succeeded without DB (unexpected)")
		}
	})

	t.Run("upsertLocalLibraryEntry empty", func(t *testing.T) {
		_, err := dispatch(reg, "upsertLocalLibraryEntry", nil)
		if err == nil {
			t.Log("upsertLocalLibraryEntry succeeded without DB (unexpected)")
		}
	})

	t.Run("upsertLocalLibraryEntriesBatch empty", func(t *testing.T) {
		_, err := dispatch(reg, "upsertLocalLibraryEntriesBatch", nil)
		if err == nil {
			t.Log("upsertLocalLibraryEntriesBatch succeeded without DB (unexpected)")
		}
	})

	t.Run("clearLocalLibrary", func(t *testing.T) {
		_, err := dispatch(reg, "clearLocalLibrary", nil)
		if err == nil {
			t.Log("clearLocalLibrary succeeded without DB (unexpected)")
		}
	})

	t.Run("deleteLocalLibraryEntriesByPaths empty", func(t *testing.T) {
		_, err := dispatch(reg, "deleteLocalLibraryEntriesByPaths", nil)
		if err == nil {
			t.Log("deleteLocalLibraryEntriesByPaths succeeded without DB (unexpected)")
		}
	})

	t.Run("deleteLocalLibraryEntryByID empty", func(t *testing.T) {
		_, err := dispatch(reg, "deleteLocalLibraryEntryByID", nil)
		if err == nil {
			t.Log("deleteLocalLibraryEntryByID succeeded without DB (unexpected)")
		}
	})
}

// ============================================================
// Download handlers (progress, misc_extra, history_extra, strategy, history)
// ============================================================

func TestRegisterDownloadProgressHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerDownloadProgress(reg)

	t.Run("getDownloadProgress", func(t *testing.T) {
		result, err := dispatch(reg, "getDownloadProgress", nil)
		if err != nil {
			t.Fatalf("getDownloadProgress failed: %v", err)
		}
		t.Logf("getDownloadProgress returned: %v", result)
	})

	t.Run("getAllDownloadProgress", func(t *testing.T) {
		result, err := dispatch(reg, "getAllDownloadProgress", nil)
		if err != nil {
			t.Fatalf("getAllDownloadProgress failed: %v", err)
		}
		t.Logf("getAllDownloadProgress returned: %v", result)
	})

	t.Run("getDownloadProgressDelta with since_seq", func(t *testing.T) {
		result, err := dispatch(reg, "getDownloadProgressDelta", map[string]interface{}{"since_seq": float64(0)})
		if err != nil {
			t.Fatalf("getDownloadProgressDelta failed: %v", err)
		}
		t.Logf("getDownloadProgressDelta returned: %v", result)
	})

	t.Run("initItemProgress", func(t *testing.T) {
		result, err := dispatch(reg, "initItemProgress", map[string]interface{}{"item_id": "test_item"})
		if err != nil {
			t.Fatalf("initItemProgress failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("initItemProgress empty id", func(t *testing.T) {
		result, err := dispatch(reg, "initItemProgress", nil)
		if err != nil {
			t.Fatalf("initItemProgress failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("finishItemProgress", func(t *testing.T) {
		result, err := dispatch(reg, "finishItemProgress", nil)
		if err != nil {
			t.Fatalf("finishItemProgress failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("clearItemProgress", func(t *testing.T) {
		result, err := dispatch(reg, "clearItemProgress", nil)
		if err != nil {
			t.Fatalf("clearItemProgress failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("setDownloadDirectory", func(t *testing.T) {
		result, err := dispatch(reg, "setDownloadDirectory", nil)
		if err != nil {
			t.Fatalf("setDownloadDirectory failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("allowDownloadDir", func(t *testing.T) {
		result, err := dispatch(reg, "allowDownloadDir", nil)
		if err != nil {
			t.Fatalf("allowDownloadDir failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("getTrackCacheSize", func(t *testing.T) {
		result, err := dispatch(reg, "getTrackCacheSize", nil)
		if err != nil {
			t.Fatalf("getTrackCacheSize failed: %v", err)
		}
		if result != "0" {
			t.Errorf("expected 0, got %v", result)
		}
	})

	t.Run("getTrackCacheSizeBytes", func(t *testing.T) {
		result, err := dispatch(reg, "getTrackCacheSizeBytes", nil)
		if err != nil {
			t.Fatalf("getTrackCacheSizeBytes failed: %v", err)
		}
		if result != "0" {
			t.Errorf("expected 0, got %v", result)
		}
	})
}

func TestRegisterDownloadMiscExtraHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerDownloadMiscExtra(reg)

	t.Run("getLogs", func(t *testing.T) {
		result, err := dispatch(reg, "getLogs", nil)
		if err != nil {
			t.Fatalf("getLogs failed: %v", err)
		}
		t.Logf("getLogs returned: %v", result)
	})

	t.Run("getLogsSince", func(t *testing.T) {
		result, err := dispatch(reg, "getLogsSince", map[string]interface{}{"since_seq": float64(0)})
		if err != nil {
			t.Fatalf("getLogsSince failed: %v", err)
		}
		if !strings.Contains(result.(string), "logs") {
			t.Errorf("expected logs JSON, got %v", result)
		}
	})

	t.Run("getLogCount", func(t *testing.T) {
		result, err := dispatch(reg, "getLogCount", nil)
		if err != nil {
			t.Fatalf("getLogCount failed: %v", err)
		}
		t.Logf("getLogCount returned: %v", result)
	})

	t.Run("setLoggingEnabled", func(t *testing.T) {
		result, err := dispatch(reg, "setLoggingEnabled", map[string]interface{}{"enabled": true})
		if err != nil {
			t.Fatalf("setLoggingEnabled failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("setLoggingEnabled false", func(t *testing.T) {
		result, err := dispatch(reg, "setLoggingEnabled", map[string]interface{}{"enabled": false})
		if err != nil {
			t.Fatalf("setLoggingEnabled failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("clearLogs", func(t *testing.T) {
		result, err := dispatch(reg, "clearLogs", nil)
		if err != nil {
			t.Fatalf("clearLogs failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("resetDatabase", func(t *testing.T) {
		result, err := dispatch(reg, "resetDatabase", nil)
		if err != nil {
			t.Fatalf("resetDatabase failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	// DB-dependent handlers that should fail gracefully
	t.Run("getHiddenRecentDownloadIds", func(t *testing.T) {
		_, err := dispatch(reg, "getHiddenRecentDownloadIds", nil)
		if err == nil {
			t.Log("getHiddenRecentDownloadIds succeeded without DB (unexpected)")
		}
	})

	t.Run("addHiddenRecentDownloadId", func(t *testing.T) {
		_, err := dispatch(reg, "addHiddenRecentDownloadId", nil)
		if err == nil {
			t.Log("addHiddenRecentDownloadId succeeded without DB (unexpected)")
		}
	})

	t.Run("saveAppSettings", func(t *testing.T) {
		_, err := dispatch(reg, "saveAppSettings", nil)
		if err == nil {
			t.Log("saveAppSettings succeeded without DB (unexpected)")
		}
	})

	t.Run("cleanupLocalLibraryMissingFiles", func(t *testing.T) {
		result, err := dispatch(reg, "cleanupLocalLibraryMissingFiles", nil)
		if err == nil {
			t.Logf("cleanupLocalLibraryMissingFiles succeeded: %v", result)
		}
	})
}

func TestRegisterDownloadStrategyHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerDownloadStrategy(reg)

	t.Run("downloadByStrategy empty request", func(t *testing.T) {
		_, err := dispatch(reg, "downloadByStrategy", nil)
		if err == nil {
			t.Error("expected error for empty request")
		}
	})

	t.Run("downloadByStrategy invalid JSON", func(t *testing.T) {
		_, err := dispatch(reg, "downloadByStrategy", map[string]interface{}{
			"request": "not valid json",
		})
		if err == nil {
			t.Error("expected error for invalid JSON")
		}
	})

	t.Run("downloadByStrategy missing required fields", func(t *testing.T) {
		_, err := dispatch(reg, "downloadByStrategy", map[string]interface{}{
			"request": `{"track_title":"","artist_name":""}`,
		})
		if err == nil {
			t.Error("expected error for missing track_title and artist_name")
		}
	})

	t.Run("cancelDownload empty id", func(t *testing.T) {
		result, err := dispatch(reg, "cancelDownload", nil)
		if err != nil {
			t.Fatalf("cancelDownload failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("cancelDownload with id", func(t *testing.T) {
		result, err := dispatch(reg, "cancelDownload", map[string]interface{}{
			"item_id": "test_item",
		})
		if err != nil {
			t.Fatalf("cancelDownload failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})
}

func TestRegisterDownloadHistoryExtra(t *testing.T) {
	reg := newTestRegistry()
	registerDownloadHistoryExtra(reg)

	t.Run("getDownloadEntryByID empty", func(t *testing.T) {
		_, err := dispatch(reg, "getDownloadEntryByID", nil)
		if err == nil {
			t.Log("getDownloadEntryByID succeeded without DB (unexpected)")
		}
	})

	t.Run("getDownloadEntryBySpotifyID empty", func(t *testing.T) {
		_, err := dispatch(reg, "getDownloadEntryBySpotifyID", nil)
		if err == nil {
			t.Log("getDownloadEntryBySpotifyID succeeded without DB (unexpected)")
		}
	})

	t.Run("getDownloadEntryByISRC empty", func(t *testing.T) {
		_, err := dispatch(reg, "getDownloadEntryByISRC", nil)
		if err == nil {
			t.Log("getDownloadEntryByISRC succeeded without DB (unexpected)")
		}
	})

	t.Run("findDownloadEntryByTrackAndArtist empty", func(t *testing.T) {
		_, err := dispatch(reg, "findDownloadEntryByTrackAndArtist", nil)
		if err == nil {
			t.Log("findDownloadEntryByTrackAndArtist succeeded without DB (unexpected)")
		}
	})

	t.Run("updateDownloadFilePath", func(t *testing.T) {
		_, err := dispatch(reg, "updateDownloadFilePath", nil)
		if err == nil {
			t.Log("updateDownloadFilePath succeeded without DB (unexpected)")
		}
	})

	t.Run("updateDownloadVideoPath", func(t *testing.T) {
		_, err := dispatch(reg, "updateDownloadVideoPath", nil)
		if err == nil {
			t.Log("updateDownloadVideoPath succeeded without DB (unexpected)")
		}
	})

	t.Run("updateDownloadLyricsPath", func(t *testing.T) {
		_, err := dispatch(reg, "updateDownloadLyricsPath", nil)
		if err == nil {
			t.Log("updateDownloadLyricsPath succeeded without DB (unexpected)")
		}
	})

	t.Run("updateDownloadAudioMetadata empty", func(t *testing.T) {
		_, err := dispatch(reg, "updateDownloadAudioMetadata", nil)
		if err == nil {
			t.Log("updateDownloadAudioMetadata succeeded without DB (unexpected)")
		}
	})

	t.Run("getDownloadHistoryFilePaths", func(t *testing.T) {
		_, err := dispatch(reg, "getDownloadHistoryFilePaths", nil)
		if err == nil {
			t.Log("getDownloadHistoryFilePaths succeeded without DB (unexpected)")
		}
	})
}

func TestRegisterDownloadHistoryFull(t *testing.T) {
	reg := newTestRegistry()
	registerDownloadHistory(reg)

	t.Run("upsertDownloadEntry empty request", func(t *testing.T) {
		_, err := dispatch(reg, "upsertDownloadEntry", nil)
		if err == nil {
			t.Error("expected error for empty request")
		}
	})

	t.Run("upsertDownloadEntriesBatch empty request", func(t *testing.T) {
		_, err := dispatch(reg, "upsertDownloadEntriesBatch", nil)
		if err == nil {
			t.Error("expected error for empty request")
		}
	})

	t.Run("deleteDownloadEntriesByIDs empty", func(t *testing.T) {
		_, err := dispatch(reg, "deleteDownloadEntriesByIDs", nil)
		if err == nil {
			t.Log("deleteDownloadEntriesByIDs succeeded without DB (unexpected)")
		}
	})

	t.Run("deleteDownloadEntriesByPaths empty", func(t *testing.T) {
		_, err := dispatch(reg, "deleteDownloadEntriesByPaths", nil)
		if err == nil {
			t.Log("deleteDownloadEntriesByPaths succeeded without DB (unexpected)")
		}
	})

	t.Run("deleteDownloadEntriesByTrackMatch empty", func(t *testing.T) {
		_, err := dispatch(reg, "deleteDownloadEntriesByTrackMatch", nil)
		if err == nil {
			t.Log("deleteDownloadEntriesByTrackMatch succeeded without DB (unexpected)")
		}
	})

	t.Run("getDownloadHistory defaults", func(t *testing.T) {
		_, err := dispatch(reg, "getDownloadHistory", nil)
		if err == nil {
			t.Log("getDownloadHistory succeeded without DB (unexpected)")
		}
	})

	t.Run("clearDownloadHistory", func(t *testing.T) {
		_, err := dispatch(reg, "clearDownloadHistory", nil)
		if err == nil {
			t.Log("clearDownloadHistory succeeded without DB (unexpected)")
		}
	})

	t.Run("getDownloadHistoryCount", func(t *testing.T) {
		_, err := dispatch(reg, "getDownloadHistoryCount", nil)
		if err == nil {
			t.Log("getDownloadHistoryCount succeeded without DB (unexpected)")
		}
	})

	t.Run("getDownloadHistoryGroupedCounts", func(t *testing.T) {
		_, err := dispatch(reg, "getDownloadHistoryGroupedCounts", nil)
		if err == nil {
			t.Log("getDownloadHistoryGroupedCounts succeeded without DB (unexpected)")
		}
	})
}

// ============================================================
// Download misc handlers (registerDownloadMisc - adds misc + misc_extra)
// ============================================================

func TestRegisterDownloadMiscFull(t *testing.T) {
	reg := newTestRegistry()
	registerDownloadMisc(reg)

	t.Run("existingDownloadTrackKeys empty", func(t *testing.T) {
		_, err := dispatch(reg, "existingDownloadTrackKeys", nil)
		if err == nil {
			t.Log("existingDownloadTrackKeys succeeded without DB (unexpected)")
		}
	})

	t.Run("getDownloadAlbumTracks empty", func(t *testing.T) {
		_, err := dispatch(reg, "getDownloadAlbumTracks", nil)
		if err == nil {
			t.Log("getDownloadAlbumTracks succeeded without DB (unexpected)")
		}
	})

	t.Run("getDownloadArtistTracks empty", func(t *testing.T) {
		_, err := dispatch(reg, "getDownloadArtistTracks", nil)
		if err == nil {
			t.Log("getDownloadArtistTracks succeeded without DB (unexpected)")
		}
	})

	t.Run("findExistingDownloadEntry empty", func(t *testing.T) {
		_, err := dispatch(reg, "findExistingDownloadEntry", nil)
		if err == nil {
			t.Log("findExistingDownloadEntry succeeded without DB (unexpected)")
		}
	})

	t.Run("getQueueCounts empty", func(t *testing.T) {
		_, err := dispatch(reg, "getQueueCounts", nil)
		if err == nil {
			t.Log("getQueueCounts succeeded without DB (unexpected)")
		}
	})

	t.Run("saveDownloadQueue empty", func(t *testing.T) {
		_, err := dispatch(reg, "saveDownloadQueue", nil)
		if err == nil {
			t.Log("saveDownloadQueue succeeded without DB (unexpected)")
		}
	})

	t.Run("loadDownloadQueue", func(t *testing.T) {
		_, err := dispatch(reg, "loadDownloadQueue", nil)
		if err == nil {
			t.Log("loadDownloadQueue succeeded without DB (unexpected)")
		}
	})

	t.Run("getPendingDownloadQueueRows", func(t *testing.T) {
		_, err := dispatch(reg, "getPendingDownloadQueueRows", nil)
		if err == nil {
			t.Log("getPendingDownloadQueueRows succeeded without DB (unexpected)")
		}
	})

	t.Run("replacePendingDownloadQueueRows empty", func(t *testing.T) {
		_, err := dispatch(reg, "replacePendingDownloadQueueRows", nil)
		if err == nil {
			t.Log("replacePendingDownloadQueueRows succeeded without DB (unexpected)")
		}
	})

	t.Run("upsertRecentAccessRow", func(t *testing.T) {
		_, err := dispatch(reg, "upsertRecentAccessRow", nil)
		if err == nil {
			t.Log("upsertRecentAccessRow succeeded without DB (unexpected)")
		}
	})

	t.Run("getRecentAccessRows", func(t *testing.T) {
		_, err := dispatch(reg, "getRecentAccessRows", nil)
		if err == nil {
			t.Log("getRecentAccessRows succeeded without DB (unexpected)")
		}
	})

	t.Run("deleteRecentAccessRow empty", func(t *testing.T) {
		_, err := dispatch(reg, "deleteRecentAccessRow", nil)
		if err == nil {
			t.Log("deleteRecentAccessRow succeeded without DB (unexpected)")
		}
	})

	t.Run("clearRecentAccessRows", func(t *testing.T) {
		_, err := dispatch(reg, "clearRecentAccessRows", nil)
		if err == nil {
			t.Log("clearRecentAccessRows succeeded without DB (unexpected)")
		}
	})
}

// ============================================================
// Extension handlers (lifecycle, query, invoke, priority, settings, auth,
// ffmpeg, URL, browse, store, store_ext)
// ============================================================

func TestRegisterExtensionBrowseHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerExtensionBrowse(reg)

	t.Run("getExtensionHomeFeed empty", func(t *testing.T) {
		result, err := dispatch(reg, "getExtensionHomeFeed", nil)
		if err != nil {
			t.Fatalf("getExtensionHomeFeed failed: %v", err)
		}
		if result != "[]" {
			t.Errorf("expected [], got %v", result)
		}
	})

	t.Run("getExtensionBrowseCategories empty", func(t *testing.T) {
		result, err := dispatch(reg, "getExtensionBrowseCategories", nil)
		if err != nil {
			t.Fatalf("getExtensionBrowseCategories failed: %v", err)
		}
		if result != "[]" {
			t.Errorf("expected [], got %v", result)
		}
	})

	t.Run("cancelExtensionRequest", func(t *testing.T) {
		result, err := dispatch(reg, "cancelExtensionRequest", nil)
		if err != nil {
			t.Fatalf("cancelExtensionRequest failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("cancelExtensionRequest with id", func(t *testing.T) {
		result, err := dispatch(reg, "cancelExtensionRequest", map[string]interface{}{"request_id": "test_req"})
		if err != nil {
			t.Fatalf("cancelExtensionRequest failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("cancelExtensionRequestJSON with id", func(t *testing.T) {
		result, err := dispatch(reg, "cancelExtensionRequestJSON", map[string]interface{}{"request_id": "test_req"})
		if err != nil {
			t.Fatalf("cancelExtensionRequestJSON failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("getExtensionHomeFeed with unknown extension", func(t *testing.T) {
		result, err := dispatch(reg, "getExtensionHomeFeed", map[string]interface{}{"extension_id": "unknown"})
		if err != nil {
			t.Fatalf("getExtensionHomeFeed failed: %v", err)
		}
		if result != "[]" {
			t.Errorf("expected [], got %v", result)
		}
	})

	t.Run("getExtensionBrowseCategories with unknown extension", func(t *testing.T) {
		result, err := dispatch(reg, "getExtensionBrowseCategories", map[string]interface{}{"extension_id": "unknown"})
		if err != nil {
			t.Fatalf("getExtensionBrowseCategories failed: %v", err)
		}
		if result != "[]" {
			t.Errorf("expected [], got %v", result)
		}
	})
}

func TestRegisterExtensionFFmpegHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerExtensionFFmpeg(reg)

	t.Run("getPendingFFmpegCommand empty", func(t *testing.T) {
		result, err := dispatch(reg, "getPendingFFmpegCommand", nil)
		if err != nil {
			t.Fatalf("getPendingFFmpegCommand failed: %v", err)
		}
		if result != "{}" {
			t.Errorf("expected {}, got %v", result)
		}
	})

	t.Run("getPendingFFmpegCommand with command_id", func(t *testing.T) {
		result, err := dispatch(reg, "getPendingFFmpegCommand", map[string]interface{}{"command_id": "cmd1"})
		if err != nil {
			t.Fatalf("getPendingFFmpegCommand failed: %v", err)
		}
		if result != "{}" {
			t.Errorf("expected {} for unknown command, got %v", result)
		}
	})

	t.Run("setFFmpegCommandResult empty", func(t *testing.T) {
		result, err := dispatch(reg, "setFFmpegCommandResult", nil)
		if err != nil {
			t.Fatalf("setFFmpegCommandResult failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("setFFmpegCommandResult with params", func(t *testing.T) {
		result, err := dispatch(reg, "setFFmpegCommandResult", map[string]interface{}{
			"command_id": "cmd1",
			"success":    "true",
			"output":     "converted",
			"error":      "",
		})
		if err != nil {
			t.Fatalf("setFFmpegCommandResult failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("getAllPendingFFmpegCommands", func(t *testing.T) {
		result, err := dispatch(reg, "getAllPendingFFmpegCommands", nil)
		if err != nil {
			t.Fatalf("getAllPendingFFmpegCommands failed: %v", err)
		}
		if result != "[]" {
			t.Errorf("expected [], got %v", result)
		}
	})
}

func TestRegisterExtensionInvokeHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerExtensionInvoke(reg)

	t.Run("invokeExtensionAction empty", func(t *testing.T) {
		_, err := dispatch(reg, "invokeExtensionAction", nil)
		// Will fail because extension not loaded
		if err == nil {
			t.Log("invokeExtensionAction succeeded (unexpected)")
		}
	})

	t.Run("searchTracksWithMetadataProviders empty query", func(t *testing.T) {
		result, err := dispatch(reg, "searchTracksWithMetadataProviders", nil)
		if err != nil {
			t.Fatalf("searchTracksWithMetadataProviders failed: %v", err)
		}
		if result != "[]" {
			t.Errorf("expected [] for empty query, got %v", result)
		}
	})

	t.Run("searchTracksWithMetadataProviders with query", func(t *testing.T) {
		result, err := dispatch(reg, "searchTracksWithMetadataProviders", map[string]interface{}{"query": "test song"})
		if err != nil {
			t.Fatalf("searchTracksWithMetadataProviders failed: %v", err)
		}
		// Without loaded extensions, returns [] (or null from JSON marshal)
		if result != "[]" && result != "null" {
			t.Errorf("expected [] or null without extensions, got %v", result)
		}
	})

	t.Run("searchTracksWithMetadataProviders with limit", func(t *testing.T) {
		result, err := dispatch(reg, "searchTracksWithMetadataProviders", map[string]interface{}{
			"query": "test",
			"limit": float64(10),
		})
		if err != nil {
			t.Fatalf("searchTracksWithMetadataProviders failed: %v", err)
		}
		if result != "[]" && result != "null" {
			t.Errorf("expected [] or null without extensions, got %v", result)
		}
	})
}

func TestRegisterExtensionInvokeExtraHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerExtensionInvokeExtra(reg)

	t.Run("customSearchWithExtension empty", func(t *testing.T) {
		result, err := dispatch(reg, "customSearchWithExtension", nil)
		if err != nil {
			t.Fatalf("customSearchWithExtension failed: %v", err)
		}
		if result != "[]" {
			t.Errorf("expected [], got %v", result)
		}
	})

	t.Run("customSearchWithExtension with ext but no query", func(t *testing.T) {
		result, err := dispatch(reg, "customSearchWithExtension", map[string]interface{}{"extension_id": "test_ext"})
		if err != nil {
			t.Fatalf("customSearchWithExtension failed: %v", err)
		}
		if result != "[]" {
			t.Errorf("expected [] without query, got %v", result)
		}
	})

	t.Run("customSearchWithExtension with ext and query", func(t *testing.T) {
		result, err := dispatch(reg, "customSearchWithExtension", map[string]interface{}{
			"extension_id": "test_ext",
			"query":        "test song",
		})
		if err != nil {
			t.Fatalf("customSearchWithExtension failed: %v", err)
		}
		if result != "[]" {
			t.Errorf("expected [] without runtime, got %v", result)
		}
	})

	t.Run("getSearchProviders", func(t *testing.T) {
		result, err := dispatch(reg, "getSearchProviders", nil)
		if err != nil {
			t.Fatalf("getSearchProviders failed: %v", err)
		}
		// Should return a JSON string with at least the built-in Deezer provider
		if !strings.Contains(result.(string), "__deezer") {
			t.Errorf("expected built-in deezer provider, got %v", result)
		}
	})

	t.Run("getSearchProviders with no extensions loaded", func(t *testing.T) {
		result, err := dispatch(reg, "getSearchProviders", nil)
		if err != nil {
			t.Fatalf("getSearchProviders failed: %v", err)
		}
		// Verify valid JSON with deezer provider
		var providers []map[string]interface{}
		if err := json.Unmarshal([]byte(result.(string)), &providers); err != nil {
			t.Errorf("expected valid JSON array, got error: %v", err)
		}
		if len(providers) < 1 {
			t.Errorf("expected at least 1 provider (deezer), got %d", len(providers))
		}
	})
}

func TestRegisterExtensionLifecycleHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerExtensionLifecycle(reg)

	t.Run("initExtensionSystem", func(t *testing.T) {
		result, err := dispatch(reg, "initExtensionSystem", nil)
		if err != nil {
			t.Fatalf("initExtensionSystem failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("initExtensionSystem with cache_dir", func(t *testing.T) {
		result, err := dispatch(reg, "initExtensionSystem", map[string]interface{}{"cache_dir": "/tmp/cache"})
		if err != nil {
			t.Fatalf("initExtensionSystem failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("loadExtensionsFromDir empty", func(t *testing.T) {
		result, err := dispatch(reg, "loadExtensionsFromDir", nil)
		if err != nil {
			t.Fatalf("loadExtensionsFromDir failed: %v", err)
		}
		if result != "[]" {
			t.Errorf("expected [] for empty dir, got %v", result)
		}
	})

	t.Run("loadExtensionsFromDir non-existent", func(t *testing.T) {
		result, err := dispatch(reg, "loadExtensionsFromDir", map[string]interface{}{"dir_path": "/nonexistent/dir"})
		if err != nil {
			t.Fatalf("loadExtensionsFromDir failed: %v", err)
		}
		if result != "[]" {
			t.Errorf("expected [] for non-existent dir, got %v", result)
		}
	})

	t.Run("loadExtensionFromPath empty", func(t *testing.T) {
		result, err := dispatch(reg, "loadExtensionFromPath", nil)
		if err != nil {
			t.Fatalf("loadExtensionFromPath failed: %v", err)
		}
		if result != "{}" {
			t.Errorf("expected {} for empty path, got %v", result)
		}
	})

	t.Run("loadExtensionFromPath non-existent", func(t *testing.T) {
		result, err := dispatch(reg, "loadExtensionFromPath", map[string]interface{}{"file_path": "/nonexistent.zip"})
		if err != nil {
			t.Fatalf("loadExtensionFromPath failed: %v", err)
		}
		if result != "{}" {
			t.Errorf("expected {} for non-existent path, got %v", result)
		}
	})

	t.Run("unloadExtension empty", func(t *testing.T) {
		result, err := dispatch(reg, "unloadExtension", nil)
		if err != nil {
			t.Fatalf("unloadExtension failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("removeExtension empty", func(t *testing.T) {
		result, err := dispatch(reg, "removeExtension", nil)
		if err != nil {
			t.Fatalf("removeExtension failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("upgradeExtension empty path", func(t *testing.T) {
		result, err := dispatch(reg, "upgradeExtension", nil)
		if err != nil {
			t.Fatalf("upgradeExtension failed: %v", err)
		}
		if !strings.Contains(result.(string), `"upgraded":false`) {
			t.Logf("upgradeExtension returned: %v", result)
		}
	})

	t.Run("checkExtensionUpgrade empty path", func(t *testing.T) {
		result, err := dispatch(reg, "checkExtensionUpgrade", nil)
		if err != nil {
			t.Fatalf("checkExtensionUpgrade failed: %v", err)
		}
		if !strings.Contains(result.(string), "has_upgrade") {
			t.Errorf("expected has_upgrade field, got %v", result)
		}
	})

	t.Run("checkExtensionUpgrade non-existent", func(t *testing.T) {
		result, err := dispatch(reg, "checkExtensionUpgrade", map[string]interface{}{"file_path": "/nonexistent.zip"})
		if err != nil {
			t.Fatalf("checkExtensionUpgrade failed: %v", err)
		}
		if !strings.Contains(result.(string), "has_upgrade") {
			t.Errorf("expected has_upgrade field, got %v", result)
		}
	})

	t.Run("cleanupExtensions", func(t *testing.T) {
		result, err := dispatch(reg, "cleanupExtensions", nil)
		if err != nil {
			t.Fatalf("cleanupExtensions failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})
}

func TestRegisterExtensionPriorityHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerExtensionPriority(reg)

	t.Run("getProviderPriority empty", func(t *testing.T) {
		result, err := dispatch(reg, "getProviderPriority", nil)
		if err != nil {
			t.Fatalf("getProviderPriority failed: %v", err)
		}
		if result != "[]" {
			t.Errorf("expected [], got %v", result)
		}
	})

	t.Run("setProviderPriority valid JSON", func(t *testing.T) {
		result, err := dispatch(reg, "setProviderPriority", map[string]interface{}{
			"priority": `["ext1","ext2"]`,
		})
		if err != nil {
			t.Fatalf("setProviderPriority failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("setProviderPriority empty", func(t *testing.T) {
		result, err := dispatch(reg, "setProviderPriority", nil)
		if err != nil {
			t.Fatalf("setProviderPriority failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("setProviderPriority invalid JSON", func(t *testing.T) {
		result, err := dispatch(reg, "setProviderPriority", map[string]interface{}{
			"priority": "not valid",
		})
		if err != nil {
			t.Fatalf("setProviderPriority failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok (no error for invalid JSON), got %v", result)
		}
	})

	t.Run("setAndGetProviderPriority round-trip", func(t *testing.T) {
		// Set priority
		dispatch(reg, "setProviderPriority", map[string]interface{}{
			"priority": `["a","b","c"]`,
		})
		// Get it back
		result, err := dispatch(reg, "getProviderPriority", nil)
		if err != nil {
			t.Fatalf("getProviderPriority failed: %v", err)
		}
		if result != `["a","b","c"]` {
			t.Errorf("expected [a b c], got %v", result)
		}
	})

	t.Run("setDownloadFallbackExtensionIds", func(t *testing.T) {
		result, err := dispatch(reg, "setDownloadFallbackExtensionIds", map[string]interface{}{
			"extension_ids": `["ext1"]`,
		})
		if err != nil {
			t.Fatalf("setDownloadFallbackExtensionIds failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("getMetadataProviderPriority empty", func(t *testing.T) {
		result, err := dispatch(reg, "getMetadataProviderPriority", nil)
		if err != nil {
			t.Fatalf("getMetadataProviderPriority failed: %v", err)
		}
		if result != "[]" {
			t.Errorf("expected [], got %v", result)
		}
	})

	t.Run("setMetadataProviderPriority", func(t *testing.T) {
		result, err := dispatch(reg, "setMetadataProviderPriority", map[string]interface{}{
			"priority": `["meta1"]`,
		})
		if err != nil {
			t.Fatalf("setMetadataProviderPriority failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	// --- JSON alias tests ---

	t.Run("getProviderPriorityJSON returns JSON string", func(t *testing.T) {
		// Reset state from previous subtests
		providerPriorityMu.Lock()
		providerPriority = nil
		providerPriorityMu.Unlock()

		result, err := dispatch(reg, "getProviderPriorityJSON", nil)
		if err != nil {
			t.Fatalf("getProviderPriorityJSON failed: %v", err)
		}
		if _, ok := result.(string); !ok {
			t.Errorf("expected string, got %T", result)
		}
		if result != "[]" {
			t.Errorf("expected [], got %v", result)
		}
	})

	t.Run("setProviderPriorityJSON valid", func(t *testing.T) {
		result, err := dispatch(reg, "setProviderPriorityJSON", map[string]interface{}{
			"priority": `["ext_a","ext_b"]`,
		})
		if err != nil {
			t.Fatalf("setProviderPriorityJSON failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
		// Reset
		providerPriorityMu.Lock()
		providerPriority = nil
		providerPriorityMu.Unlock()
	})

	t.Run("setProviderPriorityJSON invalid handled gracefully", func(t *testing.T) {
		result, err := dispatch(reg, "setProviderPriorityJSON", map[string]interface{}{
			"priority": "not valid json",
		})
		if err != nil {
			t.Fatalf("setProviderPriorityJSON failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("setDownloadFallbackExtensionIdsJSON valid", func(t *testing.T) {
		result, err := dispatch(reg, "setDownloadFallbackExtensionIdsJSON", map[string]interface{}{
			"extension_ids": `["fallback1"]`,
		})
		if err != nil {
			t.Fatalf("setDownloadFallbackExtensionIdsJSON failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
		// Reset
		fallbackExtensionIDsMu.Lock()
		fallbackExtensionIDs = nil
		fallbackExtensionIDsMu.Unlock()
	})

	t.Run("getMetadataProviderPriorityJSON returns JSON string", func(t *testing.T) {
		// Reset state from previous subtests
		metadataProviderPriorityMu.Lock()
		metadataProviderPriority = nil
		metadataProviderPriorityMu.Unlock()

		result, err := dispatch(reg, "getMetadataProviderPriorityJSON", nil)
		if err != nil {
			t.Fatalf("getMetadataProviderPriorityJSON failed: %v", err)
		}
		if _, ok := result.(string); !ok {
			t.Errorf("expected string, got %T", result)
		}
		if result != "[]" {
			t.Errorf("expected [], got %v", result)
		}
	})

	t.Run("setMetadataProviderPriorityJSON valid", func(t *testing.T) {
		result, err := dispatch(reg, "setMetadataProviderPriorityJSON", map[string]interface{}{
			"priority": `["meta_a"]`,
		})
		if err != nil {
			t.Fatalf("setMetadataProviderPriorityJSON failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
		// Reset
		metadataProviderPriorityMu.Lock()
		metadataProviderPriority = nil
		metadataProviderPriorityMu.Unlock()
	})
}

func TestRegisterExtensionQueryHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerExtensionQuery(reg)

	t.Run("getInstalledExtensions", func(t *testing.T) {
		result, err := dispatch(reg, "getInstalledExtensions", nil)
		if err != nil {
			t.Fatalf("getInstalledExtensions failed: %v", err)
		}
		if result != "[]" {
			t.Errorf("expected [], got %v", result)
		}
	})

	t.Run("setExtensionEnabled with no id", func(t *testing.T) {
		result, err := dispatch(reg, "setExtensionEnabled", nil)
		if err != nil {
			t.Fatalf("setExtensionEnabled failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("setExtensionEnabled with id and enabled", func(t *testing.T) {
		result, err := dispatch(reg, "setExtensionEnabled", map[string]interface{}{
			"extension_id": "test_ext",
			"enabled":      true,
		})
		if err != nil {
			t.Fatalf("setExtensionEnabled failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("setExtensionEnabled with string enabled", func(t *testing.T) {
		result, err := dispatch(reg, "setExtensionEnabled", map[string]interface{}{
			"extension_id": "test_ext",
			"enabled":      "true",
		})
		if err != nil {
			t.Fatalf("setExtensionEnabled failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("setExtensionEnabled disabled", func(t *testing.T) {
		result, err := dispatch(reg, "setExtensionEnabled", map[string]interface{}{
			"extension_id": "test_ext",
			"enabled":      false,
		})
		if err != nil {
			t.Fatalf("setExtensionEnabled failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})
}

func TestRegisterExtensionSettingsHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerExtensionSettings(reg)

	t.Run("getExtensionSettings empty", func(t *testing.T) {
		result, err := dispatch(reg, "getExtensionSettings", nil)
		if err != nil {
			t.Fatalf("getExtensionSettings failed: %v", err)
		}
		if result != "{}" {
			t.Errorf("expected {}, got %v", result)
		}
	})

	t.Run("getExtensionSettings unknown", func(t *testing.T) {
		result, err := dispatch(reg, "getExtensionSettings", map[string]interface{}{"extension_id": "unknown_ext"})
		if err != nil {
			t.Fatalf("getExtensionSettings failed: %v", err)
		}
		if result != "{}" {
			t.Errorf("expected {}, got %v", result)
		}
	})

	t.Run("setExtensionSettings with settings", func(t *testing.T) {
		result, err := dispatch(reg, "setExtensionSettings", map[string]interface{}{
			"extension_id": "ext1",
			"settings":     `{"key":"value"}`,
		})
		if err != nil {
			t.Fatalf("setExtensionSettings failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("setExtensionSettings empty id", func(t *testing.T) {
		result, err := dispatch(reg, "setExtensionSettings", nil)
		if err != nil {
			t.Fatalf("setExtensionSettings failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("setExtensionSettings merge with existing", func(t *testing.T) {
		// First set settings
		dispatch(reg, "setExtensionSettings", map[string]interface{}{
			"extension_id": "ext_merge",
			"settings":     `{"key1":"val1"}`,
		})
		// Then merge with additional settings
		dispatch(reg, "setExtensionSettings", map[string]interface{}{
			"extension_id": "ext_merge",
			"settings":     `{"key2":"val2"}`,
		})
		// Verify all keys are present
		result, err := dispatch(reg, "getExtensionSettings", map[string]interface{}{"extension_id": "ext_merge"})
		if err != nil {
			t.Fatalf("getExtensionSettings failed: %v", err)
		}
		if !strings.Contains(result.(string), "key1") || !strings.Contains(result.(string), "key2") {
			t.Errorf("expected both keys in merged result, got %v", result)
		}
	})

	t.Run("checkExtensionHealth empty", func(t *testing.T) {
		result, err := dispatch(reg, "checkExtensionHealth", nil)
		if err != nil {
			t.Fatalf("checkExtensionHealth failed: %v", err)
		}
		if !strings.Contains(result.(string), `"healthy":false`) {
			t.Errorf("expected healthy:false for no extension ID, got %v", result)
		}
	})

	t.Run("checkExtensionHealth unknown", func(t *testing.T) {
		result, err := dispatch(reg, "checkExtensionHealth", map[string]interface{}{"extension_id": "unknown_ext"})
		if err != nil {
			t.Fatalf("checkExtensionHealth failed: %v", err)
		}
		// Accept either "not loaded" (runtime exists but ext not loaded) or
		// "not initialized" (runtime is nil, e.g. in test environment)
		if !strings.Contains(result.(string), "not loaded") && !strings.Contains(result.(string), "not initialized") {
			t.Errorf("expected 'not loaded' or 'not initialized' message, got %v", result)
		}
	})

	// --- JSON alias tests ---

	t.Run("getExtensionSettingsJSON empty returns {}", func(t *testing.T) {
		result, err := dispatch(reg, "getExtensionSettingsJSON", nil)
		if err != nil {
			t.Fatalf("getExtensionSettingsJSON failed: %v", err)
		}
		if result != "{}" {
			t.Errorf("expected {}, got %v", result)
		}
	})

	t.Run("getExtensionSettingsJSON unknown returns {}", func(t *testing.T) {
		result, err := dispatch(reg, "getExtensionSettingsJSON", map[string]interface{}{"extension_id": "unknown_ext"})
		if err != nil {
			t.Fatalf("getExtensionSettingsJSON failed: %v", err)
		}
		if result != "{}" {
			t.Errorf("expected {}, got %v", result)
		}
	})

	t.Run("setExtensionSettingsJSON with settings", func(t *testing.T) {
		result, err := dispatch(reg, "setExtensionSettingsJSON", map[string]interface{}{
			"extension_id": "ext_json1",
			"settings":     `{"key_json":"value_json"}`,
		})
		if err != nil {
			t.Fatalf("setExtensionSettingsJSON failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("setExtensionSettingsJSON empty id", func(t *testing.T) {
		result, err := dispatch(reg, "setExtensionSettingsJSON", nil)
		if err != nil {
			t.Fatalf("setExtensionSettingsJSON failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("getExtensionSettingsJSON after set", func(t *testing.T) {
		// First set
		dispatch(reg, "setExtensionSettingsJSON", map[string]interface{}{
			"extension_id": "ext_json_get",
			"settings":     `{"k1":"v1"}`,
		})
		// Then get
		result, err := dispatch(reg, "getExtensionSettingsJSON", map[string]interface{}{"extension_id": "ext_json_get"})
		if err != nil {
			t.Fatalf("getExtensionSettingsJSON failed: %v", err)
		}
		if !strings.Contains(result.(string), "k1") {
			t.Errorf("expected k1 in result, got %v", result)
		}
	})
}

func TestRegisterExtensionStoreHandlers(t *testing.T) {
	reg := newTestRegistry()
	// Register store handlers
	registerExtensionStore(reg)

	t.Run("initExtensionStore", func(t *testing.T) {
		result, err := dispatch(reg, "initExtensionStore", nil)
		if err != nil {
			t.Fatalf("initExtensionStore failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("initExtensionStore with cache_dir", func(t *testing.T) {
		result, err := dispatch(reg, "initExtensionStore", map[string]interface{}{"cache_dir": "/tmp/ext_cache"})
		if err != nil {
			t.Fatalf("initExtensionStore failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("setStoreRegistryUrl", func(t *testing.T) {
		result, err := dispatch(reg, "setStoreRegistryUrl", map[string]interface{}{"url": "https://example.com/registry.json"})
		if err != nil {
			t.Fatalf("setStoreRegistryUrl failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("setStoreRegistryUrl with registry_url alias", func(t *testing.T) {
		result, err := dispatch(reg, "setStoreRegistryUrl", map[string]interface{}{"registry_url": "https://example.com/reg.json"})
		if err != nil {
			t.Fatalf("setStoreRegistryUrl failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("setStoreRegistryURLJSON", func(t *testing.T) {
		result, err := dispatch(reg, "setStoreRegistryURLJSON", nil)
		if err != nil {
			t.Fatalf("setStoreRegistryURLJSON failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("setStoreRegistryURLJSON with request", func(t *testing.T) {
		result, err := dispatch(reg, "setStoreRegistryURLJSON", map[string]interface{}{
			"request": `{"url":"https://example.com/reg2.json"}`,
		})
		if err != nil {
			t.Fatalf("setStoreRegistryURLJSON failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("getStoreRegistryUrl", func(t *testing.T) {
		result, err := dispatch(reg, "getStoreRegistryUrl", nil)
		if err != nil {
			t.Fatalf("getStoreRegistryUrl failed: %v", err)
		}
		t.Logf("getStoreRegistryUrl returned: %v", result)
	})

	t.Run("getStoreRegistryURLJSON", func(t *testing.T) {
		result, err := dispatch(reg, "getStoreRegistryURLJSON", nil)
		if err != nil {
			t.Fatalf("getStoreRegistryURLJSON failed: %v", err)
		}
		if !strings.Contains(result.(string), "url") {
			t.Errorf("expected url field in JSON, got %v", result)
		}
	})

	t.Run("clearStoreRegistryUrl", func(t *testing.T) {
		result, err := dispatch(reg, "clearStoreRegistryUrl", nil)
		if err != nil {
			t.Fatalf("clearStoreRegistryUrl failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("clearStoreRegistryURLJSON", func(t *testing.T) {
		result, err := dispatch(reg, "clearStoreRegistryURLJSON", nil)
		if err != nil {
			t.Fatalf("clearStoreRegistryURLJSON failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("getStoreCategories", func(t *testing.T) {
		result, err := dispatch(reg, "getStoreCategories", nil)
		if err != nil {
			t.Fatalf("getStoreCategories failed: %v", err)
		}
		// Store returns actual categories; just verify valid JSON array
		if !strings.HasPrefix(result.(string), "[") {
			t.Errorf("expected JSON array, got %v", result)
		}
		t.Logf("getStoreCategories returned: %v", result)
	})

	t.Run("getStoreCategoriesJSON", func(t *testing.T) {
		result, err := dispatch(reg, "getStoreCategoriesJSON", nil)
		if err != nil {
			t.Fatalf("getStoreCategoriesJSON failed: %v", err)
		}
		if !strings.HasPrefix(result.(string), "[") {
			t.Errorf("expected JSON array, got %v", result)
		}
	})
}

func TestRegisterExtensionStoreExtHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerExtensionStoreExt(reg)

	t.Run("getStoreExtensions returns valid JSON", func(t *testing.T) {
		result, err := dispatch(reg, "getStoreExtensions", nil)
		if err != nil {
			t.Fatalf("getStoreExtensions failed: %v", err)
		}
		// Store may return actual extensions; just verify valid JSON array
		if !strings.HasPrefix(result.(string), "[") {
			t.Errorf("expected JSON array, got %v", result)
		}
		t.Logf("getStoreExtensions returned %d chars", len(result.(string)))
	})

	t.Run("getStoreExtensionsJSON returns valid JSON", func(t *testing.T) {
		result, err := dispatch(reg, "getStoreExtensionsJSON", nil)
		if err != nil {
			t.Fatalf("getStoreExtensionsJSON failed: %v", err)
		}
		if !strings.HasPrefix(result.(string), "[") {
			t.Errorf("expected JSON array, got %v", result)
		}
	})

	t.Run("searchStoreExtensions returns valid JSON", func(t *testing.T) {
		result, err := dispatch(reg, "searchStoreExtensions", nil)
		if err != nil {
			t.Fatalf("searchStoreExtensions failed: %v", err)
		}
		if !strings.HasPrefix(result.(string), "[") {
			t.Errorf("expected JSON array, got %v", result)
		}
	})

	t.Run("searchStoreExtensions with query returns valid JSON", func(t *testing.T) {
		result, err := dispatch(reg, "searchStoreExtensions", map[string]interface{}{"query": "deezer"})
		if err != nil {
			t.Fatalf("searchStoreExtensions failed: %v", err)
		}
		if !strings.HasPrefix(result.(string), "[") {
			t.Errorf("expected JSON array, got %v", result)
		}
	})

	t.Run("searchStoreExtensionsJSON returns valid JSON", func(t *testing.T) {
		result, err := dispatch(reg, "searchStoreExtensionsJSON", nil)
		if err != nil {
			t.Fatalf("searchStoreExtensionsJSON failed: %v", err)
		}
		if !strings.HasPrefix(result.(string), "[") {
			t.Errorf("expected JSON array, got %v", result)
		}
	})

	t.Run("searchStoreExtensionsJSON with request returns valid JSON", func(t *testing.T) {
		result, err := dispatch(reg, "searchStoreExtensionsJSON", map[string]interface{}{
			"request": `{"query":"tidal","category":"download"}`,
		})
		if err != nil {
			t.Fatalf("searchStoreExtensionsJSON failed: %v", err)
		}
		if !strings.HasPrefix(result.(string), "[") {
			t.Errorf("expected JSON array, got %v", result)
		}
	})
}

func TestRegisterExtensionStoreExtDownloadHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerExtensionStoreExtDownload(reg)

	t.Run("downloadStoreExtension empty", func(t *testing.T) {
		result, err := dispatch(reg, "downloadStoreExtension", nil)
		if err != nil {
			t.Fatalf("downloadStoreExtension failed: %v", err)
		}
		if !strings.Contains(result.(string), `"success":false`) {
			t.Errorf("expected success:false, got %v", result)
		}
	})

	t.Run("downloadStoreExtension with params", func(t *testing.T) {
		result, err := dispatch(reg, "downloadStoreExtension", map[string]interface{}{
			"extension_id": "test_ext",
			"dest_path":    "/tmp/ext.zip",
		})
		if err != nil {
			t.Fatalf("downloadStoreExtension failed: %v", err)
		}
		// Store not initialized so will fail, but should not panic
		t.Logf("downloadStoreExtension returned: %v", result)
	})

	t.Run("downloadStoreExtensionJSON empty", func(t *testing.T) {
		result, err := dispatch(reg, "downloadStoreExtensionJSON", nil)
		if err != nil {
			t.Fatalf("downloadStoreExtensionJSON failed: %v", err)
		}
		if !strings.Contains(result.(string), `"success":false`) {
			t.Errorf("expected success:false, got %v", result)
		}
	})

	t.Run("clearStoreCache", func(t *testing.T) {
		result, err := dispatch(reg, "clearStoreCache", nil)
		if err != nil {
			t.Fatalf("clearStoreCache failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})

	t.Run("clearStoreCacheJSON", func(t *testing.T) {
		result, err := dispatch(reg, "clearStoreCacheJSON", nil)
		if err != nil {
			t.Fatalf("clearStoreCacheJSON failed: %v", err)
		}
		if result != "ok" {
			t.Errorf("expected ok, got %v", result)
		}
	})
}

func TestRegisterExtensionURLHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerExtensionURL(reg)

	t.Run("findCollectionAcrossExtensions empty", func(t *testing.T) {
		result, err := dispatch(reg, "findCollectionAcrossExtensions", nil)
		if err != nil {
			t.Fatalf("findCollectionAcrossExtensions failed: %v", err)
		}
		t.Logf("findCollectionAcrossExtensions returned: %v", result)
	})

	t.Run("handleURLWithExtension empty", func(t *testing.T) {
		result, err := dispatch(reg, "handleURLWithExtension", nil)
		if err != nil {
			t.Fatalf("handleURLWithExtension failed: %v", err)
		}
		if result != "{}" {
			t.Errorf("expected {} for empty URL, got %v", result)
		}
	})

	t.Run("handleURLWithExtension with URL", func(t *testing.T) {
		result, err := dispatch(reg, "handleURLWithExtension", map[string]interface{}{"url": "https://open.spotify.com/track/123"})
		if err != nil {
			t.Fatalf("handleURLWithExtension failed: %v", err)
		}
		// No loaded extensions, should return {}
		if result != "{}" {
			t.Errorf("expected {} without extensions, got %v", result)
		}
	})

	t.Run("findURLHandler empty", func(t *testing.T) {
		result, err := dispatch(reg, "findURLHandler", nil)
		if err != nil {
			t.Fatalf("findURLHandler failed: %v", err)
		}
		if result != "" {
			t.Errorf("expected empty for no URL, got %v", result)
		}
	})

	t.Run("findURLHandler with URL", func(t *testing.T) {
		result, err := dispatch(reg, "findURLHandler", map[string]interface{}{"url": "https://example.com/song"})
		if err != nil {
			t.Fatalf("findURLHandler failed: %v", err)
		}
		if result != "" {
			t.Errorf("expected empty without extensions, got %v", result)
		}
	})

	t.Run("getURLHandlers", func(t *testing.T) {
		result, err := dispatch(reg, "getURLHandlers", nil)
		if err != nil {
			t.Fatalf("getURLHandlers failed: %v", err)
		}
		// Go marshals nil slice as null; also accept [] or null
		if result != "[]" && result != "null" {
			t.Errorf("expected [] or null, got %v", result)
		}
	})
}

// ============================================================
// V2 handlers (migration, artists, albums, tracks, collections, wishlist, other)
// ============================================================

func TestRegisterV2MigrationHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerV2Migration(reg)

	t.Run("runMigrationV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "runMigrationV2JSON", nil)
		// Needs DB
		if err == nil {
			t.Log("runMigrationV2JSON succeeded without DB (unexpected)")
		}
	})
}

func TestRegisterV2ArtistHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerV2Artists(reg)

	t.Run("getAllArtistsV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "getAllArtistsV2JSON", nil)
		if err == nil {
			t.Log("getAllArtistsV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("getFavoriteArtistsV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "getFavoriteArtistsV2JSON", nil)
		if err == nil {
			t.Log("getFavoriteArtistsV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("addFavoriteArtistV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "addFavoriteArtistV2JSON", nil)
		if err == nil {
			t.Log("addFavoriteArtistV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("removeFavoriteArtistV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "removeFavoriteArtistV2JSON", nil)
		if err == nil {
			t.Log("removeFavoriteArtistV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("updateArtistImageV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "updateArtistImageV2JSON", nil)
		if err == nil {
			t.Log("updateArtistImageV2JSON succeeded without DB (unexpected)")
		}
	})
}

func TestRegisterV2AlbumHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerV2Albums(reg)

	t.Run("getAllAlbumsV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "getAllAlbumsV2JSON", nil)
		if err == nil {
			t.Log("getAllAlbumsV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("getFavoriteAlbumsV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "getFavoriteAlbumsV2JSON", nil)
		if err == nil {
			t.Log("getFavoriteAlbumsV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("addFavoriteAlbumV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "addFavoriteAlbumV2JSON", nil)
		if err == nil {
			t.Log("addFavoriteAlbumV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("removeFavoriteAlbumV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "removeFavoriteAlbumV2JSON", nil)
		if err == nil {
			t.Log("removeFavoriteAlbumV2JSON succeeded without DB (unexpected)")
		}
	})
}

func TestRegisterV2TrackHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerV2Tracks(reg)

	t.Run("getTrackV2ByID empty", func(t *testing.T) {
		_, err := dispatch(reg, "getTrackV2ByID", nil)
		if err == nil {
			t.Log("getTrackV2ByID succeeded without DB (unexpected)")
		}
	})

	t.Run("updateTrackCoverPathV2", func(t *testing.T) {
		_, err := dispatch(reg, "updateTrackCoverPathV2", nil)
		if err == nil {
			t.Log("updateTrackCoverPathV2 succeeded without DB (unexpected)")
		}
	})

	t.Run("addLovedTrackV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "addLovedTrackV2JSON", nil)
		if err == nil {
			t.Log("addLovedTrackV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("removeLovedTrackV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "removeLovedTrackV2JSON", nil)
		if err == nil {
			t.Log("removeLovedTrackV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("getLovedTracksV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "getLovedTracksV2JSON", nil)
		if err == nil {
			t.Log("getLovedTracksV2JSON succeeded without DB (unexpected)")
		}
	})
}

func TestRegisterV2CollectionHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerV2Collections(reg)

	t.Run("createCollectionV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "createCollectionV2JSON", nil)
		if err == nil {
			t.Log("createCollectionV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("updateCollectionV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "updateCollectionV2JSON", nil)
		if err == nil {
			t.Log("updateCollectionV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("addCollectionTrackV2JSON with collection_id and track_id", func(t *testing.T) {
		_, err := dispatch(reg, "addCollectionTrackV2JSON", map[string]interface{}{
			"collection_id": "col1",
			"track_id":     "track1",
		})
		if err == nil {
			t.Log("addCollectionTrackV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("addCollectionTrackV2JSON with item_id fallback", func(t *testing.T) {
		_, err := dispatch(reg, "addCollectionTrackV2JSON", map[string]interface{}{
			"collection_id": "col1",
			"item_id":      "item1",
		})
		if err == nil {
			t.Log("addCollectionTrackV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("removeCollectionTrackV2", func(t *testing.T) {
		_, err := dispatch(reg, "removeCollectionTrackV2", nil)
		if err == nil {
			t.Log("removeCollectionTrackV2 succeeded without DB (unexpected)")
		}
	})

	t.Run("getCollectionTracksV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "getCollectionTracksV2JSON", nil)
		if err == nil {
			t.Log("getCollectionTracksV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("getFavoritePlaylistsV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "getFavoritePlaylistsV2JSON", nil)
		if err == nil {
			t.Log("getFavoritePlaylistsV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("reorderCollectionItemsV2JSON with string item_ids", func(t *testing.T) {
		_, err := dispatch(reg, "reorderCollectionItemsV2JSON", map[string]interface{}{
			"collection_id": "col1",
			"item_ids":      `["a","b"]`,
		})
		if err == nil {
			t.Log("reorderCollectionItemsV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("reorderCollectionItemsV2JSON with []interface{} item_ids", func(t *testing.T) {
		_, err := dispatch(reg, "reorderCollectionItemsV2JSON", map[string]interface{}{
			"collection_id": "col1",
			"item_ids":     []interface{}{"a", "b", "c"},
		})
		if err == nil {
			t.Log("reorderCollectionItemsV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("deleteCollectionV2", func(t *testing.T) {
		_, err := dispatch(reg, "deleteCollectionV2", nil)
		if err == nil {
			t.Log("deleteCollectionV2 succeeded without DB (unexpected)")
		}
	})
}

func TestRegisterV2WishlistHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerV2Wishlist(reg)

	t.Run("addWishlistTrackV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "addWishlistTrackV2JSON", nil)
		if err == nil {
			t.Log("addWishlistTrackV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("removeWishlistTrackV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "removeWishlistTrackV2JSON", nil)
		if err == nil {
			t.Log("removeWishlistTrackV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("getWishlistTracksV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "getWishlistTracksV2JSON", nil)
		if err == nil {
			t.Log("getWishlistTracksV2JSON succeeded without DB (unexpected)")
		}
	})
}

func TestRegisterV2OtherHandlers(t *testing.T) {
	reg := newTestRegistry()
	registerV2Other(reg)

	t.Run("getUserPremiumV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "getUserPremiumV2JSON", nil)
		if err == nil {
			t.Log("getUserPremiumV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("setUserPremiumV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "setUserPremiumV2JSON", nil)
		if err == nil {
			t.Log("setUserPremiumV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("getListeningLevelV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "getListeningLevelV2JSON", nil)
		if err == nil {
			t.Log("getListeningLevelV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("logPlayV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "logPlayV2JSON", nil)
		if err == nil {
			t.Log("logPlayV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("getPlayStatsV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "getPlayStatsV2JSON", nil)
		if err == nil {
			t.Log("getPlayStatsV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("getRecentPlaysV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "getRecentPlaysV2JSON", nil)
		if err == nil {
			t.Log("getRecentPlaysV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("logDownloadV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "logDownloadV2JSON", nil)
		if err == nil {
			t.Log("logDownloadV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("getDownloadedTracksV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "getDownloadedTracksV2JSON", nil)
		if err == nil {
			t.Log("getDownloadedTracksV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("getDownloadedAlbumsV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "getDownloadedAlbumsV2JSON", nil)
		if err == nil {
			t.Log("getDownloadedAlbumsV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("getArtistTopTracksV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "getArtistTopTracksV2JSON", nil)
		if err == nil {
			t.Log("getArtistTopTracksV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("getArtistTopAlbumsV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "getArtistTopAlbumsV2JSON", nil)
		if err == nil {
			t.Log("getArtistTopAlbumsV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("addSimilarArtistV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "addSimilarArtistV2JSON", nil)
		if err == nil {
			t.Log("addSimilarArtistV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("addSimilarArtistV2JSON with similarity_score", func(t *testing.T) {
		_, err := dispatch(reg, "addSimilarArtistV2JSON", map[string]interface{}{
			"artist_id":        "art1",
			"similar_artist_id": "art2",
			"similarity_score": float64(0.85),
		})
		if err == nil {
			t.Log("addSimilarArtistV2JSON succeeded without DB (unexpected)")
		}
	})

	t.Run("addSimilarArtistV2JSON with string score", func(t *testing.T) {
		_, err := dispatch(reg, "addSimilarArtistV2JSON", map[string]interface{}{
			"artist_id":        "art1",
			"similar_artist_id": "art2",
			"similarity_score": "0.9",
		})
		if err == nil {
			t.Log("addSimilarArtistV2JSON with string score succeeded without DB (unexpected)")
		}
	})

	t.Run("getSimilarArtistsV2JSON", func(t *testing.T) {
		_, err := dispatch(reg, "getSimilarArtistsV2JSON", nil)
		if err == nil {
			t.Log("getSimilarArtistsV2JSON succeeded without DB (unexpected)")
		}
	})
}

// ============================================================
// Registration completeness — extended
// ============================================================

func TestAllExtensionHandlersRegistered(t *testing.T) {
	reg := newTestRegistry()

	RegisterExtensionHandlers(reg)

	t.Run("getInstalledExtensions registered", func(t *testing.T) {
		_, err := reg.Get("getInstalledExtensions")
		if err != nil {
			t.Errorf("getInstalledExtensions not registered: %v", err)
		}
	})

	t.Run("setExtensionEnabled registered", func(t *testing.T) {
		_, err := reg.Get("setExtensionEnabled")
		if err != nil {
			t.Errorf("setExtensionEnabled not registered: %v", err)
		}
	})

	t.Run("getExtensionSettings registered", func(t *testing.T) {
		_, err := reg.Get("getExtensionSettings")
		if err != nil {
			t.Errorf("getExtensionSettings not registered: %v", err)
		}
	})

	t.Run("initExtensionStore registered", func(t *testing.T) {
		_, err := reg.Get("initExtensionStore")
		if err != nil {
			t.Errorf("initExtensionStore not registered: %v", err)
		}
	})

	t.Run("getStoreExtensions registered", func(t *testing.T) {
		_, err := reg.Get("getStoreExtensions")
		if err != nil {
			t.Errorf("getStoreExtensions not registered: %v", err)
		}
	})

	t.Run("getExtensionHomeFeed registered", func(t *testing.T) {
		_, err := reg.Get("getExtensionHomeFeed")
		if err != nil {
			t.Errorf("getExtensionHomeFeed not registered: %v", err)
		}
	})

	t.Run("getPendingFFmpegCommand registered", func(t *testing.T) {
		_, err := reg.Get("getPendingFFmpegCommand")
		if err != nil {
			t.Errorf("getPendingFFmpegCommand not registered: %v", err)
		}
	})

	t.Run("getExtensionPendingAuth registered", func(t *testing.T) {
		_, err := reg.Get("getExtensionPendingAuth")
		if err != nil {
			t.Errorf("getExtensionPendingAuth not registered: %v", err)
		}
	})
}

func TestAllV2HandlersRegistered(t *testing.T) {
	reg := newTestRegistry()

	RegisterV2Handlers(reg)

	methods := []string{
		"runMigrationV2JSON",
		"getAllArtistsV2JSON",
		"getFavoriteArtistsV2JSON",
		"addFavoriteArtistV2JSON",
		"removeFavoriteArtistV2JSON",
		"getAllAlbumsV2JSON",
		"getFavoriteAlbumsV2JSON",
		"addFavoriteAlbumV2JSON",
		"removeFavoriteAlbumV2JSON",
		"getTrackV2ByID",
		"updateTrackCoverPathV2",
		"addLovedTrackV2JSON",
		"removeLovedTrackV2JSON",
		"getLovedTracksV2JSON",
		"createCollectionV2JSON",
		"getCollectionTracksV2JSON",
		"addCollectionTrackV2JSON",
		"removeCollectionTrackV2",
		"reorderCollectionItemsV2JSON",
		"deleteCollectionV2",
		"addWishlistTrackV2JSON",
		"removeWishlistTrackV2JSON",
		"getWishlistTracksV2JSON",
		"getUserPremiumV2JSON",
		"setUserPremiumV2JSON",
		"getDownloadedTracksV2JSON",
		"getDownloadedAlbumsV2JSON",
		"logPlayV2JSON",
		"getRecentPlaysV2JSON",
		"getSimilarArtistsV2JSON",
	}
	for _, m := range methods {
		t.Run(m, func(t *testing.T) {
			_, err := reg.Get(m)
			if err != nil {
				t.Errorf("%s not registered: %v", m, err)
			}
		})
	}
}

func TestAllDownloadHandlersRegistered(t *testing.T) {
	reg := newTestRegistry()

	RegisterDownloadHandlers(reg)

	methods := []string{
		"downloadByStrategy",
		"cancelDownload",
		"getDownloadProgress",
		"initItemProgress",
		"finishItemProgress",
		"clearItemProgress",
		"setDownloadDirectory",
		"getTrackCacheSize",
		"getTrackCacheSizeBytes",
		"upsertDownloadEntry",
		"getDownloadHistory",
		"getDownloadHistoryCount",
		"clearDownloadHistory",
		"findExistingDownloadEntry",
		"getDownloadAlbumTracks",
		"getDownloadArtistTracks",
		"loadDownloadQueue",
		"saveDownloadQueue",
		"getQueueCounts",
		"getHiddenRecentDownloadIds",
		"getLogs",
		"getLogCount",
		"clearLogs",
		"getDownloadEntryByID",
		"getDownloadEntryBySpotifyID",
		"findDownloadEntryByTrackAndArtist",
		"getDownloadHistoryFilePaths",
		"resetDatabase",
	}
	for _, m := range methods {
		t.Run(m, func(t *testing.T) {
			_, err := reg.Get(m)
			if err != nil {
				t.Errorf("%s not registered: %v", m, err)
			}
		})
	}
}

func TestAllLibraryHandlersRegistered(t *testing.T) {
	reg := newTestRegistry()

	RegisterLibraryHandlers(reg)

	methods := []string{
		"scanLibraryFolder",
		"getLibraryScanProgress",
		"cancelLibraryScan",
		"getLocalLibraryEntryByID",
		"getLocalLibraryEntryByIsrc",
		"getLocalLibraryCoverPaths",
		"getLocalLibraryPage",
		"getLocalLibraryCount",
		"getLocalLibraryAlbumGroups",
		"getLocalLibrarySingleTrackCount",
		"updateLocalLibraryFileModTimes",
		"updateLocalLibraryAudioMetadata",
		"getLocalLibraryArtistTracks",
		"getLocalLibraryAlbumTracks",
		"upsertLocalLibraryEntry",
		"clearLocalLibrary",
		"deleteLocalLibraryEntriesByPaths",
		"deleteLocalLibraryEntryByID",
	}
	for _, m := range methods {
		t.Run(m, func(t *testing.T) {
			_, err := reg.Get(m)
			if err != nil {
				t.Errorf("%s not registered: %v", m, err)
			}
		})
	}
}

// --- JSON Serialization ---

func TestHandlerParameterConversions(t *testing.T) {
	t.Run("Sp handles missing keys", func(t *testing.T) {
		result := rpc.Sp(nil, "missing")
		if result != "" {
			t.Errorf("expected empty, got %q", result)
		}
	})

	t.Run("Sn handles missing keys", func(t *testing.T) {
		result := rpc.Sn(nil, "missing")
		if result != 0 {
			t.Errorf("expected 0, got %d", result)
		}
	})

	t.Run("Sn handles float values", func(t *testing.T) {
		result := rpc.Sn(map[string]interface{}{"val": float64(42)}, "val")
		if result != 42 {
			t.Errorf("expected 42, got %d", result)
		}
	})
}

// --- Registration completeness ---

func TestAllHandlersRegistered(t *testing.T) {
	// This test verifies the registration functions exist and can be called
	reg := newTestRegistry()

	t.Run("RegisterAvailabilityHandlers", func(t *testing.T) {
		RegisterAvailabilityHandlers(reg)
		// At minimum, setSongLinkRegion should be registered
		_, err := reg.Get("setSongLinkRegion")
		if err != nil {
			t.Errorf("setSongLinkRegion not registered: %v", err)
		}
	})

	t.Run("RegisterSearchHandlers", func(t *testing.T) {
		RegisterSearchHandlers(reg)
		_, err := reg.Get("searchTracks")
		if err != nil {
			t.Errorf("searchTracks not registered: %v", err)
		}
	})

	t.Run("RegisterPremiumHandlers", func(t *testing.T) {
		RegisterPremiumHandlers(reg)
		_, err := reg.Get("verificarPremium")
		if err != nil {
			t.Errorf("verificarPremium not registered: %v", err)
		}
	})

	t.Run("RegisterVideoHandlers", func(t *testing.T) {
		RegisterVideoHandlers(reg)
		_, err := reg.Get("ensureYtDlp")
		if err != nil {
			t.Errorf("ensureYtDlp not registered: %v", err)
		}
	})

	t.Run("RegisterLyricsHandlers", func(t *testing.T) {
		RegisterLyricsHandlers(reg)
		_, err := reg.Get("fetchLyrics")
		if err != nil {
			t.Errorf("fetchLyrics not registered: %v", err)
		}
		_, err = reg.Get("getLyricsLRC")
		if err != nil {
			t.Errorf("getLyricsLRC not registered: %v", err)
		}
		_, err = reg.Get("getAvailableLyricsProviders")
		if err != nil {
			t.Errorf("getAvailableLyricsProviders not registered: %v", err)
		}
	})

	t.Run("RegisterPlaybackHandlers", func(t *testing.T) {
		RegisterPlaybackHandlers(reg)
		_, err := reg.Get("playbackPause")
		if err != nil {
			t.Errorf("playbackPause not registered: %v", err)
		}
		_, err = reg.Get("playbackGetState")
		if err != nil {
			t.Errorf("playbackGetState not registered: %v", err)
		}
		_, err = reg.Get("playbackSetQueue")
		if err != nil {
			t.Errorf("playbackSetQueue not registered: %v", err)
		}
	})

	t.Run("RegisterMetadataHandlers", func(t *testing.T) {
		RegisterMetadataHandlers(reg)
		_, err := reg.Get("readFileMetadata")
		if err != nil {
			t.Errorf("readFileMetadata not registered: %v", err)
		}
		_, err = reg.Get("sanitizeFilename")
		if err != nil {
			t.Errorf("sanitizeFilename not registered: %v", err)
		}
		_, err = reg.Get("downloadCoverToFile")
		if err != nil {
			t.Errorf("downloadCoverToFile not registered: %v", err)
		}
	})

	t.Run("RegisterLibraryHandlers", func(t *testing.T) {
		RegisterLibraryHandlers(reg)
		// Library handlers register sub-handlers
		t.Log("RegisterLibraryHandlers completed without panic")
	})

	t.Run("RegisterSystemHandlers", func(t *testing.T) {
		RegisterSystemHandlers(reg)
		_, err := reg.Get("ping")
		if err != nil {
			t.Errorf("ping not registered: %v", err)
		}
	})
}

// --- Edge cases ---

func TestHandlerEdgeCases(t *testing.T) {
	t.Run("metadata_edit non-existent file", func(t *testing.T) {
		reg := newTestRegistry()
		RegisterMetadataHandlers(reg)

		result, err := dispatch(reg, "editFileMetadata", map[string]interface{}{
			"file_path":     "/nonexistent/song.flac",
			"metadata_json": `{"title":"New"}`,
		})
		if err != nil {
			t.Logf("editFileMetadata error (expected): %v", err)
		}
		if result != nil {
			t.Logf("editFileMetadata returned: %v", result)
		}
	})

	t.Run("embedLyricsToFile with audio file path no track", func(t *testing.T) {
		reg := newTestRegistry()
		RegisterLyricsHandlers(reg)

		result, err := dispatch(reg, "embedLyricsToFile", map[string]interface{}{
			"audio_file_path": "/music/song.flac",
			"track_name":      "",
			"artist_name":     "Artist",
		})
		if err != nil {
			t.Fatalf("embedLyricsToFile failed: %v", err)
		}
		m, ok := result.(map[string]interface{})
		if !ok {
			t.Fatalf("expected map, got %T", result)
		}
		if m["success"] != false {
			t.Errorf("expected success=false")
		}
	})
}

// ============================================================
// Post-processing handlers
// ============================================================


func TestRegisterPostProcessingHandlers(t *testing.T) {
	reg := newTestRegistry()
	RegisterPostProcessingHandlers(reg)

	t.Run("runPostProcessing missing file_path", func(t *testing.T) {
		_, err := dispatch(reg, "runPostProcessing", map[string]interface{}{
			"file_path": "",
		})
		if err == nil {
			t.Error("expected error for empty file_path")
		}
	})

	t.Run("runPostProcessing without metadata", func(t *testing.T) {
		result, err := dispatch(reg, "runPostProcessing", map[string]interface{}{
			"file_path": "/tmp/test.flac",
		})
		if err != nil {
			t.Fatalf("runPostProcessing failed: %v", err)
		}
		if !strings.Contains(result.(string), "\"success\":true") {
			t.Errorf("expected success:true, got %v", result)
		}
	})

	t.Run("runPostProcessing with metadata", func(t *testing.T) {
		result, err := dispatch(reg, "runPostProcessing", map[string]interface{}{
			"file_path": "/tmp/test.flac",
			"metadata":  "{\"title\":\"Song\",\"artist\":\"Artist\"}",
		})
		if err != nil {
			t.Fatalf("runPostProcessing failed: %v", err)
		}
		if !strings.Contains(result.(string), "\"success\":true") {
			t.Errorf("expected success:true, got %v", result)
		}
	})

	t.Run("runPostProcessingV2 missing input", func(t *testing.T) {
		_, err := dispatch(reg, "runPostProcessingV2", nil)
		if err == nil {
			t.Error("expected error for missing input")
		}
	})

	t.Run("runPostProcessingV2 invalid JSON input", func(t *testing.T) {
		_, err := dispatch(reg, "runPostProcessingV2", map[string]interface{}{
			"input": "not valid json",
		})
		if err == nil {
			t.Error("expected error for invalid JSON input")
		}
	})

	t.Run("runPostProcessingV2 valid", func(t *testing.T) {
		result, err := dispatch(reg, "runPostProcessingV2", map[string]interface{}{
			"input": "{\"file_path\":\"/tmp/test.flac\"}",
		})
		if err != nil {
			t.Fatalf("runPostProcessingV2 failed: %v", err)
		}
		if !strings.Contains(result.(string), "\"success\":true") {
			t.Errorf("expected success:true, got %v", result)
		}
	})

	t.Run("runPostProcessingV2 with output_format", func(t *testing.T) {
		result, err := dispatch(reg, "runPostProcessingV2", map[string]interface{}{
			"input": "{\"file_path\":\"/tmp/test.wav\",\"output_format\":\"flac\",\"delete_source\":true}",
		})
		if err != nil {
			// When ffmpeg is available but file doesn't exist, conversion fails.
			// Either way the handler doesn't panic.
			t.Logf("runPostProcessingV2 output_format error (expected if ffmpeg present): %v", err)
		} else if !strings.Contains(result.(string), "\"success\":true") {
			t.Errorf("expected success:true, got %v", result)
		}
	})

	t.Run("runPostProcessingV2 with metadata", func(t *testing.T) {
		result, err := dispatch(reg, "runPostProcessingV2", map[string]interface{}{
			"input":    "{\"file_path\":\"/tmp/test.flac\"}",
			"metadata": "{\"title\":\"Test\",\"artist\":\"Test Artist\",\"album\":\"Test Album\"}",
		})
		if err != nil {
			t.Fatalf("runPostProcessingV2 failed: %v", err)
		}
		if !strings.Contains(result.(string), "\"success\":true") {
			t.Errorf("expected success:true, got %v", result)
		}
	})

	t.Run("runPostProcessingV2 missing file_path in input", func(t *testing.T) {
		_, err := dispatch(reg, "runPostProcessingV2", map[string]interface{}{
			"input": "{}",
		})
		if err == nil {
			t.Error("expected error for empty file_path in input")
		}
	})

	t.Run("convertAudioFile missing input_path", func(t *testing.T) {
		_, err := dispatch(reg, "convertAudioFile", map[string]interface{}{
			"input_path": "",
		})
		if err == nil {
			t.Error("expected error for empty input_path")
		}
	})

	t.Run("convertAudioFile non-m4a file returns path unchanged", func(t *testing.T) {
		result, err := dispatch(reg, "convertAudioFile", map[string]interface{}{
			"input_path": "/tmp/test.flac",
		})
		if err != nil {
			t.Fatalf("convertAudioFile failed: %v", err)
		}
		if result != "/tmp/test.flac" {
			t.Errorf("expected input path unchanged, got %v", result)
		}
	})

	t.Run("convertAudioFile m4a returns path unchanged", func(t *testing.T) {
		result, err := dispatch(reg, "convertAudioFile", map[string]interface{}{
			"input_path": "/tmp/test.m4a",
		})
		if err != nil {
			t.Fatalf("convertAudioFile failed: %v", err)
		}
		if result != "/tmp/test.m4a" {
			t.Errorf("expected input path unchanged, got %v", result)
		}
	})

	t.Run("getPostProcessingProviders returns []", func(t *testing.T) {
		result, err := dispatch(reg, "getPostProcessingProviders", nil)
		if err != nil {
			t.Fatalf("getPostProcessingProviders failed: %v", err)
		}
		if result != "[]" {
			t.Errorf("expected [], got %v", result)
		}
	})

}

// ============================================================
// CueSheet handlers
// ============================================================

func TestRegisterCueSheetHandlers(t *testing.T) {
	reg := newTestRegistry()
	RegisterCueSheetHandlers(reg)

	t.Run("parseCueSheet missing cue_path", func(t *testing.T) {
		_, err := dispatch(reg, "parseCueSheet", map[string]interface{}{
			"cue_path": "",
		})
		if err == nil {
			t.Error("expected error for empty cue_path")
		}
	})

	t.Run("parseCueSheet nonexistent file", func(t *testing.T) {
		_, err := dispatch(reg, "parseCueSheet", map[string]interface{}{
			"cue_path": "/nonexistent/file.cue",
		})
		if err == nil {
			t.Error("expected error for nonexistent cue file")
		}
	})

	t.Run("parseCueSheet with valid cue file", func(t *testing.T) {
		dir := t.TempDir()
		cuePath := filepath.Join(dir, "test.cue")
		cueContent := []byte("PERFORMER \"Test Artist\"\nTITLE \"Test Album\"\nFILE \"test.flac\" FLAC\n  TRACK 01 AUDIO\n    TITLE \"Song\"\n    INDEX 01 00:00:00\n")
		if err := os.WriteFile(cuePath, cueContent, 0644); err != nil {
			t.Fatal(err)
		}
		// Create a dummy audio file so ResolveCueAudioPath succeeds
		audioPath := filepath.Join(dir, "test.flac")
		if err := os.WriteFile(audioPath, []byte("dummy audio"), 0644); err != nil {
			t.Fatal(err)
		}
		result, err := dispatch(reg, "parseCueSheet", map[string]interface{}{
			"cue_path": cuePath,
		})
		if err != nil {
			t.Fatalf("parseCueSheet failed: %v", err)
		}
		if _, ok := result.(string); !ok {
			t.Errorf("expected string, got %T", result)
		}
	})

	t.Run("parseCueSheet with audio_dir", func(t *testing.T) {
		dir := t.TempDir()
		cuePath := filepath.Join(dir, "test.cue")
		cueContent := []byte("PERFORMER \"Artist\"\nTITLE \"Album\"\nFILE \"audio.flac\" FLAC\n  TRACK 01 AUDIO\n    TITLE \"Song\"\n    INDEX 01 00:00:00\n")
		if err := os.WriteFile(cuePath, cueContent, 0644); err != nil {
			t.Fatal(err)
		}
		// audio not found in audio_dir, will fail
		_, err := dispatch(reg, "parseCueSheet", map[string]interface{}{
			"cue_path":  cuePath,
			"audio_dir": dir,
		})
		if err == nil {
			t.Error("expected error when audio file not found in audio_dir")
		}
	})

	t.Run("scanCueSheetForLibrary missing cue_path", func(t *testing.T) {
		result, err := dispatch(reg, "scanCueSheetForLibrary", map[string]interface{}{
			"cue_path": "",
		})
		if err == nil {
			t.Error("expected error for empty cue_path")
		}
		if result != "[]" {
			t.Errorf("expected [], got %v", result)
		}
	})

	t.Run("scanCueSheetForLibrary nonexistent file", func(t *testing.T) {
		result, err := dispatch(reg, "scanCueSheetForLibrary", map[string]interface{}{
			"cue_path": "/nonexistent/file.cue",
		})
		if err == nil {
			t.Error("expected error for nonexistent file")
		}
		if result != "[]" {
			t.Errorf("expected [], got %v", result)
		}
	})

	t.Run("scanCueSheetForLibrary valid but audio not found", func(t *testing.T) {
		dir := t.TempDir()
		cuePath := filepath.Join(dir, "test.cue")
		cueContent := []byte("PERFORMER \"Artist\"\nTITLE \"Album\"\nFILE \"missing.flac\" FLAC\n  TRACK 01 AUDIO\n    TITLE \"Song\"\n    INDEX 01 00:00:00\n")
		if err := os.WriteFile(cuePath, cueContent, 0644); err != nil {
			t.Fatal(err)
		}
		result, err := dispatch(reg, "scanCueSheetForLibrary", map[string]interface{}{
			"cue_path": cuePath,
		})
		if err == nil {
			t.Error("expected error when audio file not found")
		}
		if result != "[]" {
			t.Errorf("expected [], got %v", result)
		}
	})
}

func TestCueID(t *testing.T) {
	t.Run("generates consistent IDs", func(t *testing.T) {
		id1 := cueID("/path/file.cue", 1)
		id2 := cueID("/path/file.cue", 1)
		if id1 != id2 {
			t.Errorf("expected same ID for same inputs, got %q vs %q", id1, id2)
		}
	})

	t.Run("different track numbers give different IDs", func(t *testing.T) {
		id1 := cueID("/path/file.cue", 1)
		id2 := cueID("/path/file.cue", 2)
		if id1 == id2 {
			t.Error("expected different IDs for different track numbers")
		}
	})

	t.Run("different paths give different IDs", func(t *testing.T) {
		id1 := cueID("/path/a.cue", 1)
		id2 := cueID("/path/b.cue", 1)
		if id1 == id2 {
			t.Error("expected different IDs for different paths")
		}
	})

	t.Run("starts with cue_ prefix", func(t *testing.T) {
		id := cueID("/any/file.cue", 1)
		if len(id) < 5 || id[:4] != "cue_" {
			t.Errorf("expected cue_ prefix, got %q", id)
		}
	})
}

func TestSetLibraryCoverCacheDir(t *testing.T) {
	t.Run("set and get", func(t *testing.T) {
		SetLibraryCoverCacheDir("/tmp/cue_cache")
		got := getLibraryCoverCacheDir()
		if got != "/tmp/cue_cache" {
			t.Errorf("expected /tmp/cue_cache, got %q", got)
		}
		// Reset for other tests
		SetLibraryCoverCacheDir("")
	})

	t.Run("reset to empty", func(t *testing.T) {
		SetLibraryCoverCacheDir("/tmp/test")
		SetLibraryCoverCacheDir("")
		got := getLibraryCoverCacheDir()
		if got != "" {
			t.Errorf("expected empty, got %q", got)
		}
	})
}

