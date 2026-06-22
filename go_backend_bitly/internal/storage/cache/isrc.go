package cache

import (
	"database/sql"
	"time"
)

const isrcCacheTTL = 24 * time.Hour

// ISRCCache caches genre and album artist lookups by ISRC.
type ISRCCache struct {
	db *sql.DB
}

// NewISRCCache creates a new ISRC cache.
func NewISRCCache(db *sql.DB) *ISRCCache {
	return &ISRCCache{db: db}
}

func (c *ISRCCache) ensureTable() error {
	_, err := c.db.Exec(`CREATE TABLE IF NOT EXISTS isrc_cache (
		isrc TEXT PRIMARY KEY,
		genre TEXT NOT NULL DEFAULT '',
		album_artist TEXT NOT NULL DEFAULT '',
		fetched_at INTEGER NOT NULL
	)`)
	return err
}

// ISRCCacheResult holds cached values for an ISRC.
type ISRCCacheResult struct {
	Genre       string
	AlbumArtist string
}

// Get retrieves cached data for an ISRC. Returns empty strings if not found or expired.
func (c *ISRCCache) Get(isrc string) (ISRCCacheResult, error) {
	if err := c.ensureTable(); err != nil {
		return ISRCCacheResult{}, err
	}

	var g, aa sql.NullString
	var fetchedAt int64
	err := c.db.QueryRow(
		`SELECT genre, album_artist, fetched_at FROM isrc_cache WHERE isrc = ?`,
		isrc,
	).Scan(&g, &aa, &fetchedAt)

	if err == sql.ErrNoRows {
		return ISRCCacheResult{}, nil
	}
	if err != nil {
		return ISRCCacheResult{}, err
	}

	if time.Now().Unix()-fetchedAt > int64(isrcCacheTTL.Seconds()) {
		return ISRCCacheResult{}, nil // expired
	}

	return ISRCCacheResult{Genre: g.String, AlbumArtist: aa.String}, nil
}

// Set caches genre and album artist for an ISRC.
func (c *ISRCCache) Set(isrc, genre, albumArtist string) error {
	if err := c.ensureTable(); err != nil {
		return err
	}
	_, err := c.db.Exec(
		`INSERT INTO isrc_cache (isrc, genre, album_artist, fetched_at)
		VALUES (?, ?, ?, ?)
		ON CONFLICT(isrc) DO UPDATE SET
			genre = excluded.genre,
			album_artist = excluded.album_artist,
			fetched_at = excluded.fetched_at`,
		isrc, genre, albumArtist, time.Now().Unix(),
	)
	return err
}

// Invalidate removes a cached ISRC entry.
func (c *ISRCCache) Invalidate(isrc string) error {
	if err := c.ensureTable(); err != nil {
		return err
	}
	_, err := c.db.Exec(`DELETE FROM isrc_cache WHERE isrc = ?`, isrc)
	return err
}
