package gobackend

import (
	"database/sql"
	"fmt"
	"time"
)

const isrcCacheTTL = 24 * time.Hour

type ISRCCache struct{}

func GetISRCCache() *ISRCCache {
	return &ISRCCache{}
}

func (c *ISRCCache) ensureTable() error {
	db, err := GetMasterDB()
	if err != nil {
		return fmt.Errorf("isrc cache: %w", err)
	}
	_, err = db.Exec(`CREATE TABLE IF NOT EXISTS isrc_cache (
		isrc TEXT PRIMARY KEY,
		genre TEXT NOT NULL DEFAULT '',
		album_artist TEXT NOT NULL DEFAULT '',
		fetched_at INTEGER NOT NULL
	)`)
	return err
}

type ISRCCacheResult struct {
	Genre       string
	AlbumArtist string
}

func (c *ISRCCache) Get(isrc string) (ISRCCacheResult, error) {
	g, aa, err := c.getInternal(isrc)
	return ISRCCacheResult{g, aa}, err
}

func (c *ISRCCache) getInternal(isrc string) (genre string, albumArtist string, err error) {
	if err := c.ensureTable(); err != nil {
		return "", "", err
	}

	db, err := GetMasterDB()
	if err != nil {
		return "", "", err
	}

	var g, aa sql.NullString
	var fetchedAt int64
	err = db.QueryRow(
		`SELECT genre, album_artist, fetched_at FROM isrc_cache WHERE isrc = ?`,
		isrc,
	).Scan(&g, &aa, &fetchedAt)

	if err == sql.ErrNoRows {
		return "", "", nil
	}
	if err != nil {
		return "", "", err
	}

	if time.Now().Unix()-fetchedAt > int64(isrcCacheTTL.Seconds()) {
		return "", "", nil
	}

	return g.String, aa.String, nil
}

func (c *ISRCCache) Set(isrc, genre, albumArtist string) error {
	if err := c.ensureTable(); err != nil {
		return err
	}

	db, err := GetMasterDB()
	if err != nil {
		return err
	}

	_, err = db.Exec(
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

func (c *ISRCCache) Invalidate(isrc string) error {
	if err := c.ensureTable(); err != nil {
		return err
	}

	db, err := GetMasterDB()
	if err != nil {
		return err
	}

	_, err = db.Exec(`DELETE FROM isrc_cache WHERE isrc = ?`, isrc)
	return err
}
