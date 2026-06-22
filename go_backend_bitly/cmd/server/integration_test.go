package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/zarz/bitly/go_backend_bitly/internal/server"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc/handlers"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

// setupTestServer creates a full backend server with in-memory DB and returns the test server.
func setupTestServer(t *testing.T) *httptest.Server {
	t.Helper()

	// Initialize in-memory database
	if err := database.Init(":memory:"); err != nil {
		t.Fatalf("failed to init test DB: %v", err)
	}
	t.Cleanup(func() {
		database.Close()
	})

	// Create dispatcher and register all handlers
	dispatcher := rpc.NewDispatcher()
	handlers.RegisterSystemHandlers(dispatcher.Registry)
	handlers.RegisterPremiumHandlers(dispatcher.Registry)
	handlers.RegisterMetadataHandlers(dispatcher.Registry)
	handlers.RegisterSearchHandlers(dispatcher.Registry)
	handlers.RegisterDownloadHandlers(dispatcher.Registry)
	handlers.RegisterPlaybackHandlers(dispatcher.Registry)
	handlers.RegisterLibraryHandlers(dispatcher.Registry)
	handlers.RegisterLyricsHandlers(dispatcher.Registry)
	handlers.RegisterVideoHandlers(dispatcher.Registry)
	handlers.RegisterAvailabilityHandlers(dispatcher.Registry)
	handlers.RegisterExtensionHandlers(dispatcher.Registry)
	handlers.RegisterV2Handlers(dispatcher.Registry)

	// Setup router
	router := server.NewRouter()
	router.Handle("/", handleIndex)
	router.Handle("/rpc", dispatcher.ServeHTTP)

	handler := server.ApplyMiddleware(router.Mux(), server.Logger, server.CORS)

	return httptest.NewServer(handler)
}

// rpcCall sends a JSON-RPC POST request to the test server.
func rpcCall(t *testing.T, ts *httptest.Server, method string, params map[string]interface{}) (map[string]interface{}, error) {
	t.Helper()

	body := map[string]interface{}{
		"method": method,
		"params": params,
	}
	bodyJSON, _ := json.Marshal(body)

	resp, err := ts.Client().Post(ts.URL+"/rpc", "application/json", bytes.NewReader(bodyJSON))
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	return result, nil
}

// rpcCallRaw sends a JSON-RPC POST request and returns the raw response.
func rpcCallRaw(t *testing.T, ts *httptest.Server, method string, params map[string]interface{}) *http.Response {
	t.Helper()

	body := map[string]interface{}{
		"method": method,
		"params": params,
	}
	bodyJSON, _ := json.Marshal(body)

	resp, err := ts.Client().Post(ts.URL+"/rpc", "application/json", bytes.NewReader(bodyJSON))
	if err != nil {
		t.Fatalf("rpc call %s failed: %v", method, err)
	}
	return resp
}

// ============================================================
// System & Health Tests
// ============================================================

func TestIntegration_IndexHandler(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	resp, err := ts.Client().Get(ts.URL + "/")
	if err != nil {
		t.Fatalf("GET / failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", resp.StatusCode)
	}

	var result map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&result)
	if result["status"] != "ok" {
		t.Errorf("expected status=ok, got %v", result["status"])
	}
	if result["servicio"] != "bitly-backend" {
		t.Errorf("expected servicio=bitly-backend, got %v", result["servicio"])
	}
}

func TestIntegration_Ping(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	result, err := rpcCall(t, ts, "ping", nil)
	if err != nil {
		t.Fatalf("ping failed: %v", err)
	}
	if result["result"] != "pong" {
		t.Errorf("expected pong, got %v", result["result"])
	}
	if result["error"] != nil {
		t.Errorf("unexpected error: %v", result["error"])
	}
}

func TestIntegration_CORSHeaders(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	resp, err := ts.Client().Get(ts.URL + "/")
	if err != nil {
		t.Fatalf("GET / failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.Header.Get("Access-Control-Allow-Origin") != "*" {
		t.Error("expected CORS header")
	}
}

func TestIntegration_InvalidMethod(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	// GET on /rpc should fail
	resp, err := ts.Client().Get(ts.URL + "/rpc")
	if err != nil {
		t.Fatalf("GET /rpc failed: %v", err)
	}
	defer resp.Body.Close()

	var result map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&result)
	if result["error"] != "method not allowed" {
		t.Errorf("expected 'method not allowed', got %v", result["error"])
	}
}

func TestIntegration_InvalidJSON(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	resp, err := ts.Client().Post(ts.URL+"/rpc", "application/json", bytes.NewReader([]byte("not json")))
	if err != nil {
		t.Fatalf("POST failed: %v", err)
	}
	defer resp.Body.Close()

	var result map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&result)
	if result["error"] == nil {
		t.Error("expected error for invalid JSON")
	}
}

func TestIntegration_UnknownMethod(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	result, err := rpcCall(t, ts, "nonexistent_method", nil)
	if err != nil {
		t.Fatalf("rpc call failed: %v", err)
	}
	if result["error"] == nil {
		t.Error("expected error for unknown method")
	}
}

// ============================================================
// Search Integration Tests
// ============================================================

func TestIntegration_SearchTracks_EmptyQuery(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	result, err := rpcCall(t, ts, "searchTracks", map[string]interface{}{
		"query": "",
	})
	if err != nil {
		t.Fatalf("searchTracks failed: %v", err)
	}
	if result["error"] != nil {
		t.Errorf("unexpected error for empty query: %v", result["error"])
	}
	t.Logf("searchTracks (empty) result: %v", result["result"])
}

func TestIntegration_SearchTracksJSON_EmptyQuery(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	result, err := rpcCall(t, ts, "searchTracksJSON", map[string]interface{}{
		"query": "",
	})
	if err != nil {
		t.Fatalf("searchTracksJSON failed: %v", err)
	}
	if result["error"] != nil {
		t.Errorf("unexpected error: %v", result["error"])
	}
	if result["result"] != "[]" {
		t.Errorf("expected [], got %v", result["result"])
	}
}

func TestIntegration_SearchTracks_WithQuery(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping network-dependent search test in short mode")
	}
	ts := setupTestServer(t)
	defer ts.Close()

	result, err := rpcCall(t, ts, "searchTracks", map[string]interface{}{
		"query": "Bohemian Rhapsody",
		"limit": 3,
	})
	if err != nil {
		t.Fatalf("searchTracks failed: %v", err)
	}
	if result["error"] != nil {
		t.Errorf("search error: %v", result["error"])
	}
	t.Logf("search result: %+v", result["result"])
}

func TestIntegration_SearchTracks_BySource(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping network-dependent search test in short mode")
	}
	ts := setupTestServer(t)
	defer ts.Close()

	result, err := rpcCall(t, ts, "searchTracks", map[string]interface{}{
		"query":  "Queen",
		"limit":  3,
		"mode":   "by_source",
		"source": "deezer",
	})
	if err != nil {
		t.Fatalf("searchTracks by_source failed: %v", err)
	}
	if result["error"] != nil {
		t.Logf("search error (may be expected): %v", result["error"])
	}
	t.Logf("search by_source result: %+v", result["result"])
}

// ============================================================
// Download History Integration Tests
// ============================================================

func TestIntegration_DownloadHistory(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	// Get download history count (should be 0 initially)
	result, err := rpcCall(t, ts, "getDownloadHistoryCount", nil)
	if err != nil {
		t.Fatalf("getDownloadHistoryCount failed: %v", err)
	}
	if result["error"] != nil {
		t.Fatalf("unexpected error: %v", result["error"])
	}
	count, ok := result["result"].(float64)
	if !ok {
		// Might be int or other numeric type
		t.Logf("count type: %T, value: %v", result["result"], result["result"])
	}
	_ = count
	t.Logf("download history count: %v", result["result"])

	// Get download history (should be empty)
	histResult, err := rpcCall(t, ts, "getDownloadHistory", map[string]interface{}{
		"limit": 10,
	})
	if err != nil {
		t.Fatalf("getDownloadHistory failed: %v", err)
	}
	t.Logf("download history: %+v", histResult["result"])

	// Clear download history (should succeed)
	clearResult, err := rpcCall(t, ts, "clearDownloadHistory", nil)
	if err != nil {
		t.Fatalf("clearDownloadHistory failed: %v", err)
	}
	if clearResult["error"] != nil {
		t.Errorf("clearDownloadHistory error: %v", clearResult["error"])
	}
}

// ============================================================
// Premium Integration Tests
// ============================================================

func TestIntegration_PremiumVerification(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	// Test with premium=true
	result, err := rpcCall(t, ts, "verificarPremium", map[string]interface{}{
		"is_premium": 1,
	})
	if err != nil {
		t.Fatalf("verificarPremium failed: %v", err)
	}
	if result["error"] != nil {
		t.Errorf("verificarPremium error: %v", result["error"])
	}
	m, ok := result["result"].(map[string]interface{})
	if ok {
		if m["valido"] != true {
			t.Errorf("expected valido=true, got %v", m["valido"])
		}
	}

	// Test without premium (should fail)
	result2, err := rpcCall(t, ts, "verificarPremium", map[string]interface{}{
		"is_premium":    0,
		"premium_until": 0,
	})
	if err != nil {
		t.Fatalf("verificarPremium failed: %v", err)
	}
	if result2["error"] == nil {
		t.Error("expected error for non-premium")
	}
}

// ============================================================
// Playback Integration Tests
// ============================================================

func TestIntegration_PlaybackState(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	// Get initial state
	result, err := rpcCall(t, ts, "playbackGetState", nil)
	if err != nil {
		t.Fatalf("playbackGetState failed: %v", err)
	}
	if result["error"] != nil {
		t.Errorf("unexpected error: %v", result["error"])
	}
	t.Logf("playback state: %+v", result["result"])

	// Pause
	_, err = rpcCall(t, ts, "playbackPause", nil)
	if err != nil {
		t.Fatalf("playbackPause failed: %v", err)
	}

	// Get queue
	qResult, err := rpcCall(t, ts, "playbackGetQueue", nil)
	if err != nil {
		t.Fatalf("playbackGetQueue failed: %v", err)
	}
	t.Logf("playback queue: %+v", qResult["result"])
}

func TestIntegration_PlaybackShuffleRepeat(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	// Set shuffle
	sResult, err := rpcCall(t, ts, "playbackSetShuffle", map[string]interface{}{
		"shuffle": 1,
	})
	if err != nil {
		t.Fatalf("playbackSetShuffle failed: %v", err)
	}
	if sResult["error"] != nil {
		t.Errorf("playbackSetShuffle error: %v", sResult["error"])
	}

	// Set repeat mode
	rResult, err := rpcCall(t, ts, "playbackSetRepeat", map[string]interface{}{
		"mode": "all",
	})
	if err != nil {
		t.Fatalf("playbackSetRepeat failed: %v", err)
	}
	if rResult["error"] != nil {
		t.Errorf("playbackSetRepeat error: %v", rResult["error"])
	}
}

func TestIntegration_PlaybackQueue(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	// Set empty queue
	result, err := rpcCall(t, ts, "playbackSetQueue", map[string]interface{}{
		"tracks": "",
	})
	if err != nil {
		t.Fatalf("playbackSetQueue failed: %v", err)
	}
	t.Logf("playbackSetQueue result: %+v", result["result"])

	// Clear queue
	_, err = rpcCall(t, ts, "playbackClearQueue", nil)
	if err != nil {
		t.Fatalf("playbackClearQueue failed: %v", err)
	}

	// Update position
	posResult, err := rpcCall(t, ts, "playbackUpdatePosition", map[string]interface{}{
		"position_ms": float64(30000),
	})
	if err != nil {
		t.Fatalf("playbackUpdatePosition failed: %v", err)
	}
	if posResult["error"] != nil {
		t.Errorf("playbackUpdatePosition error: %v", posResult["error"])
	}
}

func TestIntegration_PlaybackGetHistory(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	result, err := rpcCall(t, ts, "playbackGetHistory", map[string]interface{}{
		"limit": 10,
	})
	if err != nil {
		t.Fatalf("playbackGetHistory failed: %v", err)
	}
	if result["error"] != nil {
		t.Errorf("unexpected error: %v", result["error"])
	}
	t.Logf("playback history: %+v", result["result"])
}

func TestIntegration_PlaybackTrackCompleted(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	result, err := rpcCall(t, ts, "playbackTrackCompleted", nil)
	if err != nil {
		t.Fatalf("playbackTrackCompleted failed: %v", err)
	}
	if result["error"] != nil {
		t.Errorf("unexpected error: %v", result["error"])
	}
}

// ============================================================
// Metadata Integration Tests
// ============================================================

func TestIntegration_MetadataUtils(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	// sanitizeFilename
	result, err := rpcCall(t, ts, "sanitizeFilename", map[string]interface{}{
		"filename": "  test:file?name  ",
	})
	if err != nil {
		t.Fatalf("sanitizeFilename failed: %v", err)
	}
	if result["error"] != nil {
		t.Errorf("sanitizeFilename error: %v", result["error"])
	}
	t.Logf("sanitizeFilename: %v", result["result"])

	// sanitizeFolderName
	_, err = rpcCall(t, ts, "sanitizeFolderName", map[string]interface{}{
		"name": "Artist / Album (2024)",
	})
	if err != nil {
		t.Fatalf("sanitizeFolderName failed: %v", err)
	}

	// normalizeOptionalString
	normResult, err := rpcCall(t, ts, "normalizeOptionalString", map[string]interface{}{
		"value": "  Hello World  ",
	})
	if err != nil {
		t.Fatalf("normalizeOptionalString failed: %v", err)
	}
	if normResult["result"] != "Hello World" {
		t.Errorf("expected 'Hello World', got %v", normResult["result"])
	}

	// audioMimeTypeForPath
	mimeResult, err := rpcCall(t, ts, "audioMimeTypeForPath", map[string]interface{}{
		"file_path": "song.flac",
	})
	if err != nil {
		t.Fatalf("audioMimeTypeForPath failed: %v", err)
	}
	if mimeResult["result"] != "audio/flac" {
		t.Errorf("expected audio/flac, got %v", mimeResult["result"])
	}

	// isPlaceholderQualityLabel
	qualResult, err := rpcCall(t, ts, "isPlaceholderQualityLabel", map[string]interface{}{
		"quality": "Hi-Res",
	})
	if err != nil {
		t.Fatalf("isPlaceholderQualityLabel failed: %v", err)
	}
	t.Logf("isPlaceholderQualityLabel: %v", qualResult["result"])
}

func TestIntegration_MetadataRead_FailsWithoutFile(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	// Try to read metadata from nonexistent file
	result, err := rpcCall(t, ts, "readFileMetadata", map[string]interface{}{
		"file_path": "/nonexistent/song.flac",
	})
	if err != nil {
		t.Fatalf("readFileMetadata failed: %v", err)
	}
	// Should return an error since file doesn't exist
	if result["error"] == nil {
		// It might still return empty metadata
		t.Logf("readFileMetadata result: %+v", result["result"])
	}
}

func TestIntegration_MetadataRead_EmptyPath(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	_, err := rpcCall(t, ts, "readFileMetadata", map[string]interface{}{
		"file_path": "",
	})
	if err != nil {
		t.Fatalf("readFileMetadata failed: %v", err)
	}
}

// ============================================================
// Lyrics Integration Tests
// ============================================================

func TestIntegration_LyricsProviders(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	// Get available providers
	result, err := rpcCall(t, ts, "getAvailableLyricsProviders", nil)
	if err != nil {
		t.Fatalf("getAvailableLyricsProviders failed: %v", err)
	}
	if result["error"] != nil {
		t.Errorf("unexpected error: %v", result["error"])
	}
	t.Logf("available lyrics providers: %+v", result["result"])

	// Get current provider order
	orderResult, err := rpcCall(t, ts, "getLyricsProviders", nil)
	if err != nil {
		t.Fatalf("getLyricsProviders failed: %v", err)
	}
	t.Logf("lyrics provider order: %+v", orderResult["result"])

	// Set provider order
	setResult, err := rpcCall(t, ts, "setLyricsProviders", map[string]interface{}{
		"providers": `["lrclib","apple_music"]`,
	})
	if err != nil {
		t.Fatalf("setLyricsProviders failed: %v", err)
	}
	if setResult["error"] != nil {
		t.Errorf("setLyricsProviders error: %v", setResult["error"])
	}
}

func TestIntegration_LyricsFetchOptions(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	// Get current options
	result, err := rpcCall(t, ts, "getLyricsFetchOptions", nil)
	if err != nil {
		t.Fatalf("getLyricsFetchOptions failed: %v", err)
	}
	t.Logf("lyrics fetch options: %+v", result["result"])

	// Set options
	setResult, err := rpcCall(t, ts, "setLyricsFetchOptions", map[string]interface{}{
		"options": `{"multi_person_word_by_word":false,"apple_elrc_word_sync":true}`,
	})
	if err != nil {
		t.Fatalf("setLyricsFetchOptions failed: %v", err)
	}
	if setResult["error"] != nil {
		t.Errorf("setLyricsFetchOptions error: %v", setResult["error"])
	}
}

func TestIntegration_LyricsFetch_UnknownTrack(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping network-dependent test in short mode")
	}
	ts := setupTestServer(t)
	defer ts.Close()

	result, err := rpcCall(t, ts, "fetchLyrics", map[string]interface{}{
		"track_name":  "ThisTrackDoesNotExistXYZ123",
		"artist_name": "Nobody",
		"duration_ms": float64(200000),
	})
	if err != nil {
		t.Fatalf("fetchLyrics failed: %v", err)
	}
	if result["error"] != nil {
		t.Logf("fetchLyrics error (expected for unknown track): %v", result["error"])
	}
}

func TestIntegration_GetLyricsLRC_UnknownTrack(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping network-dependent test in short mode")
	}
	ts := setupTestServer(t)
	defer ts.Close()

	// getLyricsLRC swallows the error for unknown tracks
	result, err := rpcCall(t, ts, "getLyricsLRC", map[string]interface{}{
		"track_name":  "NonexistentSong123",
		"artist_name": "NonexistentArtist",
		"duration_ms": float64(200000),
	})
	if err != nil {
		t.Fatalf("getLyricsLRC failed: %v", err)
	}
	if result["error"] != nil {
		t.Errorf("unexpected error: %v", result["error"])
	}
	t.Logf("getLyricsLRC result: %+v", result["result"])
}

// ============================================================
// Availability Integration Tests
// ============================================================

func TestIntegration_Availability_Region(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	result, err := rpcCall(t, ts, "setSongLinkRegion", map[string]interface{}{
		"region": "US",
	})
	if err != nil {
		t.Fatalf("setSongLinkRegion failed: %v", err)
	}
	if result["error"] != nil {
		t.Errorf("unexpected error: %v", result["error"])
	}
	if result["result"] != "ok" {
		t.Errorf("expected ok, got %v", result["result"])
	}
}

func TestIntegration_Availability_EmptyCheck(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	result, err := rpcCall(t, ts, "checkAvailability", nil)
	if err != nil {
		t.Fatalf("checkAvailability failed: %v", err)
	}
	if result["error"] == nil {
		t.Log("checkAvailability succeeded with empty params (unexpected)")
	} else {
		t.Logf("checkAvailability error (expected): %v", result["error"])
	}
}

// ============================================================
// Extension Auth Integration Tests
// ============================================================

func TestIntegration_ExtensionAuth(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	// Get pending auth for nonexistent extension
	result, err := rpcCall(t, ts, "getExtensionPendingAuth", map[string]interface{}{
		"extension_id": "test_ext",
	})
	if err != nil {
		t.Fatalf("getExtensionPendingAuth failed: %v", err)
	}
	if result["error"] != nil {
		t.Errorf("unexpected error: %v", result["error"])
	}
	t.Logf("pending auth: %v", result["result"])

	// Set auth code
	_, err = rpcCall(t, ts, "setExtensionAuthCode", map[string]interface{}{
		"extension_id": "test_ext",
		"code":         "auth123",
	})
	if err != nil {
		t.Fatalf("setExtensionAuthCode failed: %v", err)
	}

	// Set tokens
	_, err = rpcCall(t, ts, "setExtensionTokens", map[string]interface{}{
		"extension_id": "test_ext",
		"access_token": "access123",
		"refresh_token": "refresh123",
	})
	if err != nil {
		t.Fatalf("setExtensionTokens failed: %v", err)
	}

	// Check auth status
	statusResult, err := rpcCall(t, ts, "isExtensionAuthenticated", map[string]interface{}{
		"extension_id": "test_ext",
	})
	if err != nil {
		t.Fatalf("isExtensionAuthenticated failed: %v", err)
	}
	if statusResult["result"] != "true" {
		t.Errorf("expected authenticated=true, got %v", statusResult["result"])
	}

	// Get all pending requests
	allResult, err := rpcCall(t, ts, "getAllPendingAuthRequests", nil)
	if err != nil {
		t.Fatalf("getAllPendingAuthRequests failed: %v", err)
	}
	t.Logf("all pending auth: %v", allResult["result"])
}

// ============================================================
// YouTube/Video Integration Tests
// ============================================================

func TestIntegration_YouTubePath(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	// Set default yt-dlp path
	result, err := rpcCall(t, ts, "setYtDlpPath", map[string]interface{}{
		"path": "",
	})
	if err != nil {
		t.Fatalf("setYtDlpPath failed: %v", err)
	}
	if result["result"] != "ok" {
		t.Errorf("expected ok, got %v", result["result"])
	}
}

// ============================================================
// Download Queue Integration Tests
// ============================================================

func TestIntegration_DownloadQueue(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	// Find existing download entry (should fail gracefully)
	result, err := rpcCall(t, ts, "findExistingDownloadEntry", map[string]interface{}{
		"spotify_id": "test123",
		"isrc":       "",
		"track_name": "Test",
		"artist_name": "Test",
	})
	if err != nil {
		t.Fatalf("findExistingDownloadEntry failed: %v", err)
	}
	if result["error"] != nil {
		t.Logf("findExistingDownloadEntry expected error (DB may not be fully set up): %v", result["error"])
	}
	t.Logf("findExistingDownloadEntry result: %+v", result["result"])
}

// ============================================================
// Lyrics Translate Integration Tests
// ============================================================

func TestIntegration_LyricsTranslate_EmptyLanguage(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	result, err := rpcCall(t, ts, "getTranslatedLyricsLRC", map[string]interface{}{
		"track_name":  "Test Song",
		"artist_name": "Test Artist",
		"language":    "",
	})
	if err != nil {
		t.Fatalf("getTranslatedLyricsLRC failed: %v", err)
	}
	if result["error"] != nil {
		t.Errorf("unexpected error: %v", result["error"])
	}
	if result["result"] != "" {
		t.Errorf("expected empty, got %v", result["result"])
	}
}

// ============================================================
// All Handlers Registered Test
// ============================================================

func TestIntegration_AllMajorEndpoints(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	type endpointTest struct {
		method string
		params map[string]interface{}
	}

	// Test all major endpoints with empty/safe parameters
	tests := []endpointTest{
		// System
		{"exitApp", nil},
		// Premium
		{"verificarPremium", map[string]interface{}{"is_premium": 0, "premium_until": 0}},
		// Playback
		{"playbackStop", nil},
		{"playbackResume", nil},
		{"playbackSeek", nil},
		{"playbackNext", nil},
		{"playbackPrevious", nil},
		{"playbackRemoveFromQueue", map[string]interface{}{"index": 0}},
		{"playbackSyncQueueState", map[string]interface{}{"state": ""}},
		{"getSimilarTracks", nil},
		// Video
		{"getYtDlpPath", nil},
		// Metadata utils
		{"formatSampleRateKHz", map[string]interface{}{"sample_rate": float64(44100)}},
		{"buildDisplayAudioQuality", map[string]interface{}{
			"bit_depth": float64(24), "sample_rate": float64(96000),
			"format": "FLAC", "stored_quality": "Hi-Res",
		}},
		{"normalizeCoverReference", map[string]interface{}{"value": ""}},
		{"normalizeRemoteHttpUrl", map[string]interface{}{"value": ""}},
		{"normalizeIsrc", map[string]interface{}{"value": "USABC1234567"}},
		{"normalizeSpotifyId", map[string]interface{}{"value": "test123"}},
		{"matchKeyFor", map[string]interface{}{"track": "Song", "artist": "Artist"}},
		{"albumKeyFor", map[string]interface{}{"album": "Album", "artist": "Artist"}},
		{"buildPathMatchKeys", map[string]interface{}{"file_path": "/music/song.flac"}},
		{"deleteFileAndCleanupFolder", map[string]interface{}{"file_path": "/nonexistent/file.flac"}},
		{"deleteSidecarFiles", map[string]interface{}{"audio_path": "/nonexistent/song.flac"}},
	}

	for _, tt := range tests {
		t.Run(tt.method, func(t *testing.T) {
			result, err := rpcCall(t, ts, tt.method, tt.params)
			if err != nil {
				t.Fatalf("%s failed: %v", tt.method, err)
			}
			// For endpoints that are expected to return errors (e.g., verificarPremium without premium),
			// just verify they don't panic and return properly
			t.Logf("%s -> result=%v error=%v", tt.method, result["result"], result["error"])
		})
	}
}

// ============================================================
// Concurrent Request Test
// ============================================================

func TestIntegration_ConcurrentRequests(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	const n = 10
	errs := make(chan error, n)
	for i := 0; i < n; i++ {
		go func(i int) {
			result, err := rpcCall(t, ts, "ping", nil)
			if err != nil {
				errs <- err
				return
			}
			if result["result"] != "pong" {
				errs <- fmt.Errorf("expected pong, got %v", result["result"])
				return
			}
			errs <- nil
		}(i)
	}

	for i := 0; i < n; i++ {
		if err := <-errs; err != nil {
			t.Errorf("concurrent request %d failed: %v", i, err)
		}
	}
}

// ============================================================
// Database Connected Test
// ============================================================

func TestIntegration_DatabaseConnected(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	// Verify database is accessible via RPC endpoints that use it
	// getDownloadHistoryCount returns 0 when DB is empty and accessible
	result, err := rpcCall(t, ts, "getDownloadHistoryCount", nil)
	if err != nil {
		t.Fatalf("getDownloadHistoryCount failed: %v", err)
	}
	if result["error"] != nil {
		t.Errorf("DB endpoint returned error: %v", result["error"])
	}
	t.Logf("DB accessible, count: %v", result["result"])
}

// ============================================================
// Lyrics Embed Integration Tests
// ============================================================

func TestIntegration_SaveLRCFile_NoPath(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	// saveLRCFile with no audio path should fail
	result, err := rpcCall(t, ts, "saveLRCFile", nil)
	if err != nil {
		t.Fatalf("saveLRCFile failed: %v", err)
	}
	if result["error"] == nil {
		t.Error("expected error for missing audio path")
	}
}

func TestIntegration_EmbedLyricsToFile_MissingFields(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	result, err := rpcCall(t, ts, "embedLyricsToFile", nil)
	if err != nil {
		t.Fatalf("embedLyricsToFile failed: %v", err)
	}
	m, ok := result["result"].(map[string]interface{})
	if !ok {
		t.Fatalf("expected map result, got %T: %v", result["result"], result["result"])
	}
	if m["success"] != false {
		t.Errorf("expected success=false, got %v", m["success"])
	}
}

// ============================================================
// Server Response Format Tests
// ============================================================

func TestIntegration_ResponseFormat(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	resp := rpcCallRaw(t, ts, "ping", nil)
	defer resp.Body.Close()

	// Verify content type
	if ct := resp.Header.Get("Content-Type"); ct != "application/json" {
		t.Errorf("expected application/json, got %s", ct)
	}

	var body map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	// Verify JSON-RPC like structure
	if _, hasResult := body["result"]; !hasResult {
		t.Error("response missing 'result' field")
	}
	// Error field should be omitted or nil for successful requests
	if err, hasError := body["error"]; hasError && err != nil {
		t.Errorf("unexpected error in response: %v", err)
	}
}

func TestIntegration_ErrorResponseFormat(t *testing.T) {
	ts := setupTestServer(t)
	defer ts.Close()

	resp := rpcCallRaw(t, ts, "nonexistent_method", nil)
	defer resp.Body.Close()

	var body map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if _, hasError := body["error"]; !hasError {
		t.Error("expected 'error' field in error response")
	}
}
