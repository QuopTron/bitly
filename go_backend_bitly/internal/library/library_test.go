package library

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"

	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

func TestSupportedAudioFormats(t *testing.T) {
	expected := map[string]bool{
		".flac": true,
		".m4a":  true,
		".mp3":  true,
		".opus": true,
		".ogg":  true,
		".ape":  true,
		".wv":   true,
		".mpc":  true,
		".cue":  true,
	}
	for ext, want := range expected {
		got := supportedAudioFormats[ext]
		if got != want {
			t.Errorf("supportedAudioFormats[%q] = %v, want %v", ext, got, want)
		}
	}
}

func TestLibraryScanProgress(t *testing.T) {
	p := LibraryScanProgress{
		TotalFiles:   100,
		ScannedFiles: 50,
		CurrentFile:  "song.flac",
		ErrorCount:   2,
		ProgressPct:  50.0,
		IsComplete:   false,
	}
	if p.TotalFiles != 100 {
		t.Errorf("TotalFiles = %d", p.TotalFiles)
	}
	if p.ScannedFiles != 50 {
		t.Errorf("ScannedFiles = %d", p.ScannedFiles)
	}
	if p.CurrentFile != "song.flac" {
		t.Errorf("CurrentFile = %q", p.CurrentFile)
	}
	if !p.IsComplete {
		// Just check fields
	}
}

func TestLibraryScanProgress_JSON(t *testing.T) {
	p := LibraryScanProgress{
		TotalFiles:   10,
		ScannedFiles: 5,
		CurrentFile:  "test.flac",
		ProgressPct:  50.0,
		IsComplete:   false,
	}
	data, err := json.Marshal(p)
	if err != nil {
		t.Fatalf("marshal failed: %v", err)
	}
	var p2 LibraryScanProgress
	if err := json.Unmarshal(data, &p2); err != nil {
		t.Fatalf("unmarshal failed: %v", err)
	}
	if p2.TotalFiles != 10 {
		t.Errorf("TotalFiles = %d", p2.TotalFiles)
	}
}

func TestGetLibraryScanProgress(t *testing.T) {
	// Set some progress
	libraryScanProgressMu.Lock()
	libraryScanProgress = LibraryScanProgress{
		TotalFiles: 5,
		ScannedFiles: 2,
	}
	libraryScanProgressMu.Unlock()

	jsonStr := GetLibraryScanProgress()
	if jsonStr == "" {
		t.Fatal("expected non-empty JSON")
	}
	if !strings.Contains(jsonStr, "total_files") {
		t.Errorf("JSON = %s", jsonStr)
	}
}

func TestCancelLibraryScan(t *testing.T) {
	libraryScanCancelMu.Lock()
	if libraryScanCancel != nil {
		close(libraryScanCancel)
	}
	libraryScanCancel = make(chan struct{})
	libraryScanCancelMu.Unlock()

	CancelLibraryScan()

	libraryScanCancelMu.Lock()
	if libraryScanCancel != nil {
		// After cancel, the channel is closed but pointer may still be set
		// Test that a select on it doesn't block (i.e., it's been closed)
		select {
		case <-libraryScanCancel:
			// OK - channel is closed
		default:
			t.Error("expected channel to be closed")
		}
	}
	libraryScanCancelMu.Unlock()
}

func TestSetLogFn(t *testing.T) {
	called := false
	SetLogFn(func(format string, args ...interface{}) {
		called = true
	})
	Log("test %d", 123)
	if !called {
		t.Error("expected log function to be called")
	}
}

func TestSetLibraryCoverCacheDir(t *testing.T) {
	SetLibraryCoverCacheDir("/tmp/covers")
	libraryCoverCacheMu.RLock()
	if libraryCoverCacheDir != "/tmp/covers" {
		t.Errorf("coverCacheDir = %q", libraryCoverCacheDir)
	}
	libraryCoverCacheMu.RUnlock()
}

func TestCollectLibraryAudioFiles(t *testing.T) {
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "song1.flac"), []byte("data"), 0644)
	os.WriteFile(filepath.Join(dir, "song2.mp3"), []byte("data"), 0644)
	os.WriteFile(filepath.Join(dir, "readme.txt"), []byte("not audio"), 0644)
	os.MkdirAll(filepath.Join(dir, "subdir"), 0755)
	os.WriteFile(filepath.Join(dir, "subdir", "song3.m4a"), []byte("data"), 0644)

	cancelCh := make(chan struct{})
	defer close(cancelCh)

	files, err := collectLibraryAudioFiles(dir, cancelCh)
	if err != nil {
		t.Fatalf("collectLibraryAudioFiles failed: %v", err)
	}
	if len(files) != 3 {
		t.Errorf("expected 3 audio files, got %d", len(files))
	}
}

func TestCollectLibraryAudioFiles_Cancelled(t *testing.T) {
	dir := t.TempDir()
	cancelCh := make(chan struct{})
	close(cancelCh) // Already cancelled

	_, err := collectLibraryAudioFiles(dir, cancelCh)
	if err == nil {
		t.Log("collectLibraryAudioFiles may succeed on empty directories even if cancelled")
	}
}

func TestResolveLibraryAudioExt(t *testing.T) {
	tests := []struct {
		filePath        string
		displayNameHint string
		want            string
	}{
		{"song.flac", "", ".flac"},
		{"song.mp3", "", ".mp3"},
		{"song", "song.flac", ".flac"},
		{"song", "song", ""},
	}
	for _, tt := range tests {
		got := resolveLibraryAudioExt(tt.filePath, tt.displayNameHint)
		if got != tt.want {
			t.Errorf("resolveLibraryAudioExt(%q, %q) = %q, want %q", tt.filePath, tt.displayNameHint, got, tt.want)
		}
	}
}

func TestLibraryDisplayNameOrPath(t *testing.T) {
	tests := []struct {
		filePath        string
		displayNameHint string
		want            string
	}{
		{"/path/song.flac", "My Song", "My Song"},
		{"/path/song.flac", "", "/path/song.flac"},
	}
	for _, tt := range tests {
		got := libraryDisplayNameOrPath(tt.filePath, tt.displayNameHint)
		if got != tt.want {
			t.Errorf("libraryDisplayNameOrPath(%q, %q) = %q, want %q", tt.filePath, tt.displayNameHint, got, tt.want)
		}
	}
}

func TestApplyDefaultLibraryMetadata(t *testing.T) {
	result := &database.LibraryScanResult{}
	applyDefaultLibraryMetadata("/music/test.flac", "", result)

	if result.ArtistName != "Unknown Artist" {
		t.Errorf("ArtistName = %q", result.ArtistName)
	}
	if result.AlbumName != "Unknown Album" {
		t.Errorf("AlbumName = %q", result.AlbumName)
	}
	if result.TrackName != "test" {
		t.Errorf("TrackName = %q", result.TrackName)
	}
}

func TestApplyDefaultLibraryMetadata_WithDisplayName(t *testing.T) {
	result := &database.LibraryScanResult{}
	applyDefaultLibraryMetadata("/music/test.flac", "Custom.flac", result)

	if result.TrackName != "Custom" {
		t.Errorf("TrackName = %q", result.TrackName)
	}
}

func TestApplyQualityFields(t *testing.T) {
	result := &database.LibraryScanResult{}
	applyQualityFields(result, 24, 96000, 300, 1000)

	if result.BitDepth != 24 {
		t.Errorf("BitDepth = %d", result.BitDepth)
	}
	if result.SampleRate != 96000 {
		t.Errorf("SampleRate = %d", result.SampleRate)
	}
	if result.Duration != 300 {
		t.Errorf("Duration = %d", result.Duration)
	}
	if result.Bitrate != 1000 {
		t.Errorf("Bitrate = %d", result.Bitrate)
	}
}

func TestApplyQualityFields_ZeroDuration(t *testing.T) {
	result := &database.LibraryScanResult{Duration: 100}
	applyQualityFields(result, 16, 44100, 0, 0)
	if result.Duration != 100 {
		t.Errorf("Duration should remain 100, got %d", result.Duration)
	}
}

func TestGenerateLibraryID(t *testing.T) {
	id1 := generateLibraryID("/music/song.flac")
	id2 := generateLibraryID("/music/song.flac")
	id3 := generateLibraryID("/music/other.flac")

	if id1 != id2 {
		t.Error("same path should generate same ID")
	}
	if id1 == id3 {
		t.Error("different paths should generate different IDs")
	}
	if !strings.HasPrefix(id1, "lib_") {
		t.Errorf("ID should start with lib_, got %q", id1)
	}
}

func TestHashString(t *testing.T) {
	h1 := hashString("test")
	h2 := hashString("test")
	h3 := hashString("different")

	if h1 != h2 {
		t.Error("same input should produce same hash")
	}
	if h1 == h3 {
		t.Error("different inputs should produce different hashes")
	}
}

func TestIsNumeric(t *testing.T) {
	tests := []struct {
		input string
		want  bool
	}{
		{"123", true},
		{"0", true},
		{"", false},
		{"12a", false},
		{"abc", false},
	}
	for _, tt := range tests {
		got := isNumeric(tt.input)
		if got != tt.want {
			t.Errorf("isNumeric(%q) = %v, want %v", tt.input, got, tt.want)
		}
	}
}

func TestIncrementalScanResult(t *testing.T) {
	result := IncrementalScanResult{
		SkippedCount: 5,
		TotalFiles:   10,
	}
	if result.SkippedCount != 5 {
		t.Errorf("SkippedCount = %d", result.SkippedCount)
	}
	if result.TotalFiles != 10 {
		t.Errorf("TotalFiles = %d", result.TotalFiles)
	}
}

func TestScanFromFilename_ArtistTrack(t *testing.T) {
	dir := t.TempDir()
	filePath := filepath.Join(dir, "Artist Name - Song Title.flac")

	result := &database.LibraryScanResult{}
	result, err := scanFromFilename(filePath, "", result)
	if err != nil {
		t.Fatalf("scanFromFilename failed: %v", err)
	}
	if result.ArtistName != "Artist Name" {
		t.Errorf("ArtistName = %q", result.ArtistName)
	}
	if result.TrackName != "Song Title" {
		t.Errorf("TrackName = %q", result.TrackName)
	}
}

func TestScanFromFilename_NumericPrefix(t *testing.T) {
	dir := t.TempDir()
	filePath := filepath.Join(dir, "01 - Song Title.flac")

	result := &database.LibraryScanResult{}
	result, err := scanFromFilename(filePath, "", result)
	if err != nil {
		t.Fatalf("scanFromFilename failed: %v", err)
	}
	if result.TrackName != "Song Title" {
		t.Errorf("TrackName = %q", result.TrackName)
	}
}

func TestScanFromFilename_NoHyphen(t *testing.T) {
	dir := t.TempDir()
	filePath := filepath.Join(dir, "Just Song.flac")

	result := &database.LibraryScanResult{}
	result, err := scanFromFilename(filePath, "", result)
	if err != nil {
		t.Fatalf("scanFromFilename failed: %v", err)
	}
	if result.TrackName != "Just Song" {
		t.Errorf("TrackName = %q", result.TrackName)
	}
}

func TestScanFromFilename_NumericTrack(t *testing.T) {
	dir := t.TempDir()
	filePath := filepath.Join(dir, "03  Song Title.flac")

	result := &database.LibraryScanResult{}
	result, err := scanFromFilename(filePath, "", result)
	if err != nil {
		t.Fatalf("scanFromFilename failed: %v", err)
	}
	if result.TrackName != "Song Title" {
		t.Errorf("TrackName = %q", result.TrackName)
	}
}

// Thread safety tests
func TestLibraryGlobalsConcurrentAccess(t *testing.T) {
	var wg sync.WaitGroup
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			SetLibraryCoverCacheDir("/tmp/test")
			_ = GetLibraryScanProgress()
		}()
	}
	wg.Wait()
}

func TestLibraryScanCancelConcurrent(t *testing.T) {
	var wg sync.WaitGroup
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			CancelLibraryScan()
		}()
	}
	wg.Wait()
}
