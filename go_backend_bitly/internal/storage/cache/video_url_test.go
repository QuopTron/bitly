package cache

import (
	"database/sql"
	"testing"
	"time"

	_ "github.com/ncruces/go-sqlite3/driver"
)

func openVideoURLTestDB(t testing.TB) *VideoURLCache {
	t.Helper()
	db, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatalf("failed to open in-memory SQLite: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	return NewVideoURLCache(db)
}

func TestVideoURLCache_GetMissing(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping VideoURLCache test in short mode")
	}
	c := openVideoURLTestDB(t)

	url, err := c.Get("Nonexistent Song", "Nonexistent Artist")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if url != "" {
		t.Fatalf("expected empty string for missing entry, got %q", url)
	}
}

func TestVideoURLCache_SetAndGet(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping VideoURLCache test in short mode")
	}
	c := openVideoURLTestDB(t)

	err := c.Set("Test Song", "Test Artist", "https://youtube.com/watch?v=test123")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	url, err := c.Get("Test Song", "Test Artist")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if url != "https://youtube.com/watch?v=test123" {
		t.Fatalf("expected 'https://youtube.com/watch?v=test123', got %q", url)
	}
}

func TestVideoURLCache_GetDifferentTrack(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping VideoURLCache test in short mode")
	}
	c := openVideoURLTestDB(t)

	c.Set("Song A", "Artist A", "https://example.com/a")
	c.Set("Song B", "Artist B", "https://example.com/b")

	url, err := c.Get("Song A", "Artist A")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if url != "https://example.com/a" {
		t.Fatalf("expected 'https://example.com/a', got %q", url)
	}

	url, err = c.Get("Song B", "Artist B")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if url != "https://example.com/b" {
		t.Fatalf("expected 'https://example.com/b', got %q", url)
	}
}

func TestVideoURLCache_Overwrite(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping VideoURLCache test in short mode")
	}
	c := openVideoURLTestDB(t)

	c.Set("Test Song", "Test Artist", "https://youtube.com/watch?v=old")
	c.Set("Test Song", "Test Artist", "https://youtube.com/watch?v=new")

	url, err := c.Get("Test Song", "Test Artist")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if url != "https://youtube.com/watch?v=new" {
		t.Fatalf("expected 'https://youtube.com/watch?v=new' after overwrite, got %q", url)
	}
}

func TestVideoURLCache_SameNameDifferentArtist(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping VideoURLCache test in short mode")
	}
	c := openVideoURLTestDB(t)

	c.Set("Same Title", "Artist A", "https://example.com/a")
	c.Set("Same Title", "Artist B", "https://example.com/b")

	urlA, _ := c.Get("Same Title", "Artist A")
	urlB, _ := c.Get("Same Title", "Artist B")
	if urlA != "https://example.com/a" {
		t.Fatalf("expected a, got %q", urlA)
	}
	if urlB != "https://example.com/b" {
		t.Fatalf("expected b, got %q", urlB)
	}
}

func TestVideoURLCache_Clear(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping VideoURLCache test in short mode")
	}
	c := openVideoURLTestDB(t)

	c.Set("Song A", "Artist A", "https://example.com/a")
	c.Set("Song B", "Artist B", "https://example.com/b")

	count, err := c.Count()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if count != 2 {
		t.Fatalf("expected count 2, got %d", count)
	}

	err = c.Clear()
	if err != nil {
		t.Fatalf("unexpected error on Clear: %v", err)
	}

	count, err = c.Count()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if count != 0 {
		t.Fatalf("expected count 0 after Clear, got %d", count)
	}
}

func TestVideoURLCache_Count(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping VideoURLCache test in short mode")
	}
	c := openVideoURLTestDB(t)

	count, err := c.Count()
	if err != nil {
		t.Fatalf("unexpected error for empty cache: %v", err)
	}
	if count != 0 {
		t.Fatalf("expected count 0 for empty cache, got %d", count)
	}

	c.Set("Song A", "Artist A", "https://example.com/a")
	count, _ = c.Count()
	if count != 1 {
		t.Fatalf("expected count 1, got %d", count)
	}

	c.Set("Song B", "Artist B", "https://example.com/b")
	count, _ = c.Count()
	if count != 2 {
		t.Fatalf("expected count 2, got %d", count)
	}
}

func TestVideoURLCache_ExpiredEntry(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping VideoURLCache test in short mode")
	}
	c := openVideoURLTestDB(t)

	c.ensureTable()
	old := time.Now().Add(-48 * time.Hour).Unix()
	c.db.Exec(`INSERT INTO video_url_cache (id, track_name, artist_name, url, source, cached_at) VALUES (?, ?, ?, ?, '', ?)`,
		"Test Song||Test Artist", "Test Song", "Test Artist", "https://youtube.com/watch?v=expired", old)

	url, err := c.Get("Test Song", "Test Artist")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if url != "" {
		t.Fatalf("expected empty string for expired entry, got %q", url)
	}
}

func TestVideoURLCache_ClearEmptyCache(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping VideoURLCache test in short mode")
	}
	c := openVideoURLTestDB(t)

	err := c.Clear()
	if err != nil {
		t.Fatalf("unexpected error on Clear empty cache: %v", err)
	}
}

func TestVideoURLCache_MultipleEntries(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping VideoURLCache test in short mode")
	}
	c := openVideoURLTestDB(t)

	entries := []struct {
		track  string
		artist string
		url    string
	}{
		{"Song A", "Artist A", "https://example.com/a"},
		{"Song B", "Artist B", "https://example.com/b"},
		{"Song C", "Artist C", "https://example.com/c"},
	}

	for _, e := range entries {
		if err := c.Set(e.track, e.artist, e.url); err != nil {
			t.Fatalf("Set(%q, %q) failed: %v", e.track, e.artist, err)
		}
	}

	for _, e := range entries {
		url, err := c.Get(e.track, e.artist)
		if err != nil {
			t.Fatalf("Get(%q, %q) failed: %v", e.track, e.artist, err)
		}
		if url != e.url {
			t.Fatalf("entry %q/%q: expected URL %q, got %q", e.track, e.artist, e.url, url)
		}
	}
}
