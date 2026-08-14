package gobackend

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// TestEvictCovers verifies that evictCoversLimit deletes the OLDEST files
// first until the directory fits under the cap (LRU by mtime).
func TestEvictCovers(t *testing.T) {
	dir := t.TempDir()
	const fileSize = 300 * 1024 // 300KB each
	base := time.Now().Add(-time.Hour)
	for i := 0; i < 5; i++ {
		data := make([]byte, fileSize)
		path := filepath.Join(dir, "cover_"+string(rune('a'+i))+".jpg")
		if err := os.WriteFile(path, data, 0644); err != nil {
			t.Fatalf("write %s: %v", path, err)
		}
		// Oldest first: cover_a is the oldest, cover_e the newest.
		mod := base.Add(time.Duration(i) * time.Minute)
		if err := os.Chtimes(path, mod, mod); err != nil {
			t.Fatalf("chtimes %s: %v", path, err)
		}
	}

	// 5 × 300KB = 1.5MB > 1MB cap → should remove the 2 oldest, keep 3.
	evictCoversLimit(dir, 1)

	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatalf("read dir: %v", err)
	}
	if len(entries) != 3 {
		t.Fatalf("expected 3 covers after eviction, got %d", len(entries))
	}
	// The survivors must be the newest (c, d, e), not the oldest.
	names := map[string]bool{}
	for _, e := range entries {
		names[e.Name()] = true
	}
	for _, gone := range []string{"cover_a.jpg", "cover_b.jpg"} {
		if names[gone] {
			t.Errorf("oldest cover %s should have been evicted", gone)
		}
	}
	for _, keep := range []string{"cover_c.jpg", "cover_d.jpg", "cover_e.jpg"} {
		if !names[keep] {
			t.Errorf("newest cover %s should have been kept", keep)
		}
	}
}

// TestEvictCoversUnderCap verifies that a directory already under the cap is
// left untouched.
func TestEvictCoversUnderCap(t *testing.T) {
	dir := t.TempDir()
	data := make([]byte, 100*1024)
	for i := 0; i < 5; i++ {
		if err := os.WriteFile(filepath.Join(dir, "c"+string(rune('a'+i))+".jpg"), data, 0644); err != nil {
			t.Fatalf("write: %v", err)
		}
	}
	evictCoversLimit(dir, 1) // 500KB total < 1MB
	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatalf("read dir: %v", err)
	}
	if len(entries) != 5 {
		t.Fatalf("expected all 5 covers kept, got %d", len(entries))
	}
}

// TestGetStreamCacheStatsShape verifies the stats payload matches the fields
// the Flutter settings UI reads.
func TestGetStreamCacheStatsShape(t *testing.T) {
	prevDir, prevMode := downloadDir, userMode
	defer func() { downloadDir, userMode = prevDir, prevMode }()
	downloadDir = t.TempDir()
	userMode = "premium"

	// Drop a fake stream cache file and a cover.
	sc := filepath.Join(downloadDir, ".stream_cache")
	co := filepath.Join(downloadDir, ".covers")
	for _, d := range []string{sc, co} {
		if err := os.MkdirAll(d, 0755); err != nil {
			t.Fatalf("mkdir %s: %v", d, err)
		}
	}
	if err := os.WriteFile(filepath.Join(sc, "track1.flac"), make([]byte, 2*1024*1024), 0644); err != nil {
		t.Fatalf("write stream file: %v", err)
	}
	if err := os.WriteFile(filepath.Join(co, "cover.jpg"), make([]byte, 50*1024), 0644); err != nil {
		t.Fatalf("write cover: %v", err)
	}

	var stats map[string]interface{}
	if err := json.Unmarshal([]byte(GetStreamCacheStats()), &stats); err != nil {
		t.Fatalf("parse stats: %v", err)
	}
	if _, ok := stats["total_size_bytes"]; !ok {
		t.Error("missing total_size_bytes")
	}
	if n, _ := stats["file_count"].(float64); n != 2 {
		t.Errorf("expected 2 cached files, got %v", stats["file_count"])
	}
	if _, ok := stats["max_cache_mb"]; !ok {
		t.Error("missing max_cache_mb")
	}
	if _, ok := stats["level_limit_mb"]; !ok {
		t.Error("missing level_limit_mb")
	}
	if stats["user_level"] != "premium" {
		t.Errorf("expected user_level premium, got %v", stats["user_level"])
	}
}
