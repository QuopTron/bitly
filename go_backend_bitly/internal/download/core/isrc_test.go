package core

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func resetISRCIndexCache() {
	isrcIndexCacheMu.Lock()
	isrcIndexCache = make(map[string]*ISRCIndex)
	isrcIndexCacheMu.Unlock()
}

func TestISRCIndex_Lookup_NonExistent(t *testing.T) {
	idx := &ISRCIndex{index: make(map[string]string)}
	path, err := idx.Lookup("USRC48700001")
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
	if path != "" {
		t.Errorf("expected empty path for non-existent ISRC, got '%s'", path)
	}
}

func TestISRCIndex_Lookup_EmptyISRC(t *testing.T) {
	idx := &ISRCIndex{index: make(map[string]string)}
	path, err := idx.Lookup("")
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
	if path != "" {
		t.Errorf("expected empty path for empty ISRC, got '%s'", path)
	}
}

func TestISRCIndex_AddAndLookup(t *testing.T) {
	idx := &ISRCIndex{index: make(map[string]string)}
	idx.Add("USRC48700001", "/path/to/track.flac")

	path, err := idx.Lookup("USRC48700001")
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
	if path != "/path/to/track.flac" {
		t.Errorf("expected '/path/to/track.flac', got '%s'", path)
	}
}

func TestISRCIndex_AddCaseInsensitive(t *testing.T) {
	idx := &ISRCIndex{index: make(map[string]string)}
	idx.Add("usrc48700001", "/path/track.flac")

	result, err := idx.Lookup("USRC48700001")
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
	if result != "/path/track.flac" {
		t.Errorf("expected '/path/track.flac', got '%s'", result)
	}

	result2, err := idx.Lookup("USRC48700001")
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
	if result2 != "/path/track.flac" {
		t.Errorf("expected '/path/track.flac', got '%s'", result2)
	}
}

func TestISRCIndex_LookupCaseInsensitive(t *testing.T) {
	idx := &ISRCIndex{index: make(map[string]string)}
	idx.Add("USRC48700001", "/path/track.flac")

	path, err := idx.Lookup("usrc48700001")
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
	if path != "/path/track.flac" {
		t.Errorf("expected '/path/track.flac', got '%s'", path)
	}
}

func TestISRCIndex_Add_EmptyISRC(t *testing.T) {
	idx := &ISRCIndex{index: make(map[string]string)}
	idx.Add("", "/path/track.flac")
	if len(idx.index) != 0 {
		t.Errorf("expected empty index, got %d entries", len(idx.index))
	}
}

func TestISRCIndex_Add_EmptyFilePath(t *testing.T) {
	idx := &ISRCIndex{index: make(map[string]string)}
	idx.Add("USRC48700001", "")
	if len(idx.index) != 0 {
		t.Errorf("expected empty index, got %d entries", len(idx.index))
	}
}

func TestISRCIndex_Add_OverwritesExisting(t *testing.T) {
	idx := &ISRCIndex{index: make(map[string]string)}
	idx.Add("USRC48700001", "/old/path.flac")
	idx.Add("USRC48700001", "/new/path.flac")

	path, _ := idx.Lookup("USRC48700001")
	if path != "/new/path.flac" {
		t.Errorf("expected '/new/path.flac', got '%s'", path)
	}
}

func TestISRCIndex_Remove(t *testing.T) {
	idx := &ISRCIndex{index: make(map[string]string)}
	idx.Add("USRC48700001", "/path/track.flac")
	idx.remove("USRC48700001")

	path, err := idx.Lookup("USRC48700001")
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
	if path != "" {
		t.Errorf("expected empty path after remove, got '%s'", path)
	}
}

func TestISRCIndex_RemoveCaseInsensitive(t *testing.T) {
	idx := &ISRCIndex{index: make(map[string]string)}
	idx.Add("USRC48700001", "/path/track.flac")
	idx.remove("usrc48700001")

	path, _ := idx.Lookup("USRC48700001")
	if path != "" {
		t.Error("expected empty after case-insensitive remove")
	}
}

func TestISRCIndex_Remove_EmptyISRC(t *testing.T) {
	idx := &ISRCIndex{index: make(map[string]string)}
	idx.Add("USRC48700001", "/path/track.flac")
	idx.remove("")
	// Should not panic and should not remove anything
	path, _ := idx.Lookup("USRC48700001")
	if path == "" {
		t.Error("remove with empty ISRC should not affect index")
	}
}

func TestISRCIndex_Remove_NonExistent(t *testing.T) {
	idx := &ISRCIndex{index: make(map[string]string)}
	idx.remove("NONEXISTENT")
	// Should not panic
}

func TestISRCIndex_MultipleEntries(t *testing.T) {
	idx := &ISRCIndex{index: make(map[string]string)}
	entries := map[string]string{
		"USRC48700001": "/path/a.flac",
		"USRC48700002": "/path/b.flac",
		"USRC48700003": "/path/c.flac",
	}
	for isrc, fp := range entries {
		idx.Add(isrc, fp)
	}

	for isrc, expectedFP := range entries {
		gotFP, err := idx.Lookup(isrc)
		if err != nil {
			t.Errorf("Lookup(%s) error: %v", isrc, err)
		}
		if gotFP != expectedFP {
			t.Errorf("Lookup(%s): expected '%s', got '%s'", isrc, expectedFP, gotFP)
		}
	}

	idx.remove("USRC48700002")

	if path, _ := idx.Lookup("USRC48700002"); path != "" {
		t.Error("removed entry should not be found")
	}
	if path, _ := idx.Lookup("USRC48700001"); path != "/path/a.flac" {
		t.Error("non-removed entry should still exist")
	}
	if path, _ := idx.Lookup("USRC48700003"); path != "/path/c.flac" {
		t.Error("non-removed entry should still exist")
	}
}

func TestGetISRCIndex_ReturnsSingleton(t *testing.T) {
	resetISRCIndexCache()
	dir := t.TempDir()

	idx1 := GetISRCIndex(dir)
	idx2 := GetISRCIndex(dir)

	if idx1 != idx2 {
		t.Error("GetISRCIndex should return the same instance for the same dir")
	}

	if idx1.outputDir != dir {
		t.Errorf("outputDir mismatch: '%s' vs '%s'", idx1.outputDir, dir)
	}
}

func TestGetISRCIndex_EmptyDir(t *testing.T) {
	resetISRCIndexCache()
	idx := GetISRCIndex("")
	if idx == nil {
		t.Fatal("expected non-nil index")
	}
	if idx.index == nil {
		t.Fatal("index map should be initialized")
	}
	if idx.outputDir != "" {
		t.Errorf("expected empty outputDir, got '%s'", idx.outputDir)
	}
}

func TestGetISRCIndex_DifferentDirs(t *testing.T) {
	resetISRCIndexCache()
	dir1 := t.TempDir()
	dir2 := t.TempDir()

	idx1 := GetISRCIndex(dir1)
	idx2 := GetISRCIndex(dir2)

	if idx1 == idx2 {
		t.Error("different directories should have different index instances")
	}
}

func TestISRCIndex_LookupAfterAdd(t *testing.T) {
	idx := &ISRCIndex{index: make(map[string]string)}
	idx.Add("USRC48700001", "/path/track.flac")
	idx.Add("USRC48700002", "/path/track2.flac")

	path1, _ := idx.Lookup("USRC48700001")
	path2, _ := idx.Lookup("USRC48700002")

	if path1 != "/path/track.flac" {
		t.Errorf("expected track.flac, got '%s'", path1)
	}
	if path2 != "/path/track2.flac" {
		t.Errorf("expected track2.flac, got '%s'", path2)
	}
}

func TestISRCIndex_ConcurrentAddLookup(t *testing.T) {
	idx := &ISRCIndex{index: make(map[string]string)}
	const goroutines = 20
	done := make(chan struct{}, goroutines)

	for i := 0; i < goroutines; i++ {
		go func(n int) {
			isrc := string(rune('A'+n%26)) + "SRC" + string(rune('0'+n/10%10))
			fp := "/path/track_" + string(rune('0'+n%10)) + ".flac"
			idx.Add(isrc, fp)
			idx.Lookup(isrc)
			done <- struct{}{}
		}(i)
	}

	for i := 0; i < goroutines; i++ {
		<-done
	}
	// Should not deadlock or panic
}

func TestInvalidateISRCCache(t *testing.T) {
	resetISRCIndexCache()
	dir := t.TempDir()

	idx1 := GetISRCIndex(dir)
	InvalidateISRCCache(dir)

	isrcIndexCacheMu.RLock()
	_, exists := isrcIndexCache[dir]
	isrcIndexCacheMu.RUnlock()

	if exists {
		t.Error("cache entry should be removed after InvalidateISRCCache")
	}

	idx2 := GetISRCIndex(dir)
	if idx1 == idx2 {
		t.Error("after invalidate should create new index instance")
	}
}

func TestCheckFileExists(t *testing.T) {
	dir := t.TempDir()
	existingFile := filepath.Join(dir, "exists.txt")
	missingFile := filepath.Join(dir, "missing.txt")

	if err := os.WriteFile(existingFile, []byte("hello"), 0644); err != nil {
		t.Fatal(err)
	}

	if !CheckFileExists(existingFile) {
		t.Error("existing file should return true")
	}
	if CheckFileExists(missingFile) {
		t.Error("missing file should return false")
	}
	if CheckFileExists(dir) {
		t.Error("directory should return false")
	}
}

func TestCheckFileExists_EmptyFile(t *testing.T) {
	dir := t.TempDir()
	emptyFile := filepath.Join(dir, "empty.txt")
	if err := os.WriteFile(emptyFile, []byte{}, 0644); err != nil {
		t.Fatal(err)
	}
	if CheckFileExists(emptyFile) {
		t.Error("empty file should return false")
	}
}

func TestAddToISRCIndex(t *testing.T) {
	resetISRCIndexCache()
	dir := t.TempDir()

	// With no cache entry, AddToISRCIndex is a no-op
	AddToISRCIndex(dir, "USRC48700001", "/path/track.flac")

	// GetISRCIndex first to populate cache, then add
	idx := GetISRCIndex(dir)
	AddToISRCIndex(dir, "USRC48700001", "/path/track.flac")

	path, _ := idx.Lookup("USRC48700001")
	if path != "/path/track.flac" {
		t.Errorf("expected '/path/track.flac', got '%s'", path)
	}
}

func TestAddToISRCIndex_EmptyParams(t *testing.T) {
	resetISRCIndexCache()
	dir := t.TempDir()
	GetISRCIndex(dir)

	AddToISRCIndex(dir, "", "/path/track.flac")
	AddToISRCIndex("", "USRC48700001", "/path/track.flac")
	AddToISRCIndex(dir, "USRC48700001", "")

	isrcIndexCacheMu.RLock()
	idx := isrcIndexCache[dir]
	isrcIndexCacheMu.RUnlock()

	if len(idx.index) != 0 {
		t.Error("empty params should not add to index")
	}
}

func TestISRCIndex_BuildTime(t *testing.T) {
	resetISRCIndexCache()
	idx := &ISRCIndex{
		index:     make(map[string]string),
		buildTime: time.Now(),
	}
	if idx.buildTime.IsZero() {
		t.Error("buildTime should not be zero")
	}
}

func TestCheckISRCExists(t *testing.T) {
	resetISRCIndexCache()
	dir := t.TempDir()

	// Empty ISRC -> returns ("", nil)
	path, err := CheckISRCExists(dir, "")
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
	if path != "" {
		t.Errorf("expected empty path for empty ISRC, got '%s'", path)
	}

	// Non-existent ISRC
	path, err = CheckISRCExists(dir, "NONEXISTENT")
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
	if path != "" {
		t.Errorf("expected empty for non-existent ISRC, got '%s'", path)
	}
}

func TestPreBuildISRCIndex(t *testing.T) {
	resetISRCIndexCache()
	dir := t.TempDir()

	err := PreBuildISRCIndex(dir)
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}

	isrcIndexCacheMu.RLock()
	idx, exists := isrcIndexCache[dir]
	isrcIndexCacheMu.RUnlock()

	if !exists {
		t.Error("index should be cached after PreBuildISRCIndex")
	}
	if idx == nil {
		t.Fatal("index should not be nil")
	}
}

func TestPreBuildISRCIndex_EmptyDir(t *testing.T) {
	err := PreBuildISRCIndex("")
	if err == nil {
		t.Error("expected error for empty directory")
	}
}
