package cache

import (
	"database/sql"
	"testing"
	"time"

	_ "github.com/ncruces/go-sqlite3/driver"
)

func openTestDB(t testing.TB) *ISRCCache {
	t.Helper()
	db, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatalf("failed to open in-memory SQLite: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	return NewISRCCache(db)
}

func TestISRCCache_GetMissing(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping ISRC cache test in short mode")
	}
	c := openTestDB(t)

	res, err := c.Get("USABC1234567")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if res.Genre != "" || res.AlbumArtist != "" {
		t.Fatal("expected empty result for missing ISRC")
	}
}

func TestISRCCache_SetAndGet(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping ISRC cache test in short mode")
	}
	c := openTestDB(t)

	err := c.Set("USABC1234567", "Rock", "Some Artist")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	res, err := c.Get("USABC1234567")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if res.Genre != "Rock" {
		t.Fatalf("expected genre Rock, got %q", res.Genre)
	}
	if res.AlbumArtist != "Some Artist" {
		t.Fatalf("expected album artist 'Some Artist', got %q", res.AlbumArtist)
	}
}

func TestISRCCache_Overwrite(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping ISRC cache test in short mode")
	}
	c := openTestDB(t)

	c.Set("USABC1234567", "Rock", "Artist A")
	c.Set("USABC1234567", "Pop", "Artist B")

	res, err := c.Get("USABC1234567")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if res.Genre != "Pop" {
		t.Fatalf("expected genre Pop after overwrite, got %q", res.Genre)
	}
	if res.AlbumArtist != "Artist B" {
		t.Fatalf("expected album artist 'Artist B', got %q", res.AlbumArtist)
	}
}

func TestISRCCache_Invalidate(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping ISRC cache test in short mode")
	}
	c := openTestDB(t)

	c.Set("USABC1234567", "Rock", "Artist A")

	err := c.Invalidate("USABC1234567")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	res, err := c.Get("USABC1234567")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if res.Genre != "" || res.AlbumArtist != "" {
		t.Fatal("expected empty result after invalidation")
	}
}

func TestISRCCache_InvalidateNonExistent(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping ISRC cache test in short mode")
	}
	c := openTestDB(t)

	err := c.Invalidate("NONEXISTENT")
	if err != nil {
		t.Fatalf("expected no error when invalidating missing key, got %v", err)
	}
}

func TestISRCCache_ExpiredEntry(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping ISRC cache test in short mode")
	}
	c := openTestDB(t)

	c.ensureTable()
	old := time.Now().Add(-48 * time.Hour).Unix()
	c.db.Exec(`INSERT INTO isrc_cache (isrc, genre, album_artist, fetched_at) VALUES (?, ?, ?, ?)`,
		"USABC1234567", "Rock", "Artist A", old)

	res, err := c.Get("USABC1234567")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if res.Genre != "" || res.AlbumArtist != "" {
		t.Fatal("expected empty result for expired entry")
	}
}

func TestISRCCache_MultipleEntries(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping ISRC cache test in short mode")
	}
	c := openTestDB(t)

	entries := []struct {
		isrc        string
		genre       string
		albumArtist string
	}{
		{"USABC1234567", "Rock", "Artist A"},
		{"USABC7654321", "Pop", "Artist B"},
		{"USABC1111111", "Jazz", "Artist C"},
	}

	for _, e := range entries {
		if err := c.Set(e.isrc, e.genre, e.albumArtist); err != nil {
			t.Fatalf("Set(%q) failed: %v", e.isrc, err)
		}
	}

	for _, e := range entries {
		res, err := c.Get(e.isrc)
		if err != nil {
			t.Fatalf("Get(%q) failed: %v", e.isrc, err)
		}
		if res.Genre != e.genre {
			t.Fatalf("ISRC %q: expected genre %q, got %q", e.isrc, e.genre, res.Genre)
		}
		if res.AlbumArtist != e.albumArtist {
			t.Fatalf("ISRC %q: expected album artist %q, got %q", e.isrc, e.albumArtist, res.AlbumArtist)
		}
	}
}

func TestISRCCache_EmptyStrings(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping ISRC cache test in short mode")
	}
	c := openTestDB(t)

	err := c.Set("USABC1234567", "", "")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	res, err := c.Get("USABC1234567")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if res.Genre != "" {
		t.Fatalf("expected empty genre, got %q", res.Genre)
	}
	if res.AlbumArtist != "" {
		t.Fatalf("expected empty album artist, got %q", res.AlbumArtist)
	}
}
