package cache

import (
	"database/sql"
	"fmt"
	"time"
)

const videoURLCacheTTL = 24 * time.Hour

// VideoURLCache caches YouTube video stream URLs by track/artist name.
type VideoURLCache struct {
	db *sql.DB
}

// NewVideoURLCache creates a new video URL cache.
func NewVideoURLCache(db *sql.DB) *VideoURLCache {
	return &VideoURLCache{db: db}
}

func (c *VideoURLCache) ensureTable() error {
	_, err := c.db.Exec(`CREATE TABLE IF NOT EXISTS video_url_cache (
		id TEXT PRIMARY KEY,
		track_name TEXT NOT NULL,
		artist_name TEXT NOT NULL,
		url TEXT NOT NULL,
		source TEXT NOT NULL DEFAULT '',
		cached_at INTEGER NOT NULL
	)`)
	if err != nil {
		return err
	}
	_, err = c.db.Exec(`CREATE INDEX IF NOT EXISTS idx_video_url_cache_names ON video_url_cache(track_name, artist_name)`)
	if err != nil {
		return err
	}
	_, err = c.db.Exec(`CREATE INDEX IF NOT EXISTS idx_video_url_cache_cached_at ON video_url_cache(cached_at)`)
	return err
}

func cacheID(trackName, artistName string) string {
	return fmt.Sprintf("%s||%s", trackName, artistName)
}

// Get retrieves a cached video URL for the given track/artist.
// Returns empty string if not found or expired.
func (c *VideoURLCache) Get(trackName, artistName string) (string, error) {
	if err := c.ensureTable(); err != nil {
		return "", err
	}

	id := cacheID(trackName, artistName)
	var url string
	var cachedAt int64
	err := c.db.QueryRow(
		`SELECT url, cached_at FROM video_url_cache WHERE id = ?`,
		id,
	).Scan(&url, &cachedAt)

	if err == sql.ErrNoRows {
		return "", nil
	}
	if err != nil {
		return "", err
	}

	if time.Now().Unix()-cachedAt > int64(videoURLCacheTTL.Seconds()) {
		return "", nil // expired
	}

	return url, nil
}

// Set caches a video URL for the given track/artist.
func (c *VideoURLCache) Set(trackName, artistName, url string) error {
	if err := c.ensureTable(); err != nil {
		return err
	}

	id := cacheID(trackName, artistName)
	_, err := c.db.Exec(
		`INSERT INTO video_url_cache (id, track_name, artist_name, url, source, cached_at)
		VALUES (?, ?, ?, ?, '', ?)
		ON CONFLICT(id) DO UPDATE SET
			url = excluded.url,
			cached_at = excluded.cached_at`,
		id, trackName, artistName, url, time.Now().Unix(),
	)
	return err
}

// Clear removes all entries from the video URL cache.
func (c *VideoURLCache) Clear() error {
	if err := c.ensureTable(); err != nil {
		return err
	}
	_, err := c.db.Exec(`DELETE FROM video_url_cache`)
	return err
}

// Count returns the number of entries in the video URL cache.
func (c *VideoURLCache) Count() (int, error) {
	if err := c.ensureTable(); err != nil {
		return 0, err
	}
	var count int
	err := c.db.QueryRow(`SELECT COUNT(*) FROM video_url_cache`).Scan(&count)
	if err != nil {
		return 0, err
	}
	return count, nil
}
