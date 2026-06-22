package database

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"
	"time"
)

// AddFavoriteAlbumV2 adds an album to favorites.
func AddFavoriteAlbumV2(albumID, name, artistID, artistName, coverURL, provider string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	now := time.Now().UTC().Format(time.RFC3339)
	normalizedAlbum := strings.ToLower(strings.TrimSpace(name))

	var existingArtistID string
	err = db.QueryRow("SELECT id FROM artists WHERE id = ?", artistID).Scan(&existingArtistID)
	if err == sql.ErrNoRows {
		normalizedArtist := strings.ToLower(strings.TrimSpace(artistName))
		_, err = db.Exec(`
			INSERT INTO artists (id, name, normalized_name, provider, created_at)
			VALUES (?, ?, ?, ?, ?)
		`, artistID, artistName, normalizedArtist, provider, now)
		if err != nil {
			return fmt.Errorf("insert artist for album favorite: %w", err)
		}
	}

	var existingAlbumID string
	err = db.QueryRow("SELECT id FROM albums WHERE id = ?", albumID).Scan(&existingAlbumID)
	if err == sql.ErrNoRows {
		_, err = db.Exec(`
			INSERT INTO albums (id, artist_id, name, normalized_name, cover_url, provider, created_at)
			VALUES (?, ?, ?, ?, ?, ?, ?)
		`, albumID, artistID, name, normalizedAlbum, coverURL, provider, now)
		if err != nil {
			return fmt.Errorf("insert album for favorite: %w", err)
		}
	}

	_, err = db.Exec("INSERT OR IGNORE INTO favorite_albums (album_id, added_at) VALUES (?, ?)", albumID, now)
	if err != nil {
		return fmt.Errorf("add favorite album: %w", err)
	}
	return nil
}

// GetFavoriteAlbumsV2 returns all favorite albums as JSON.
func GetFavoriteAlbumsV2() (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}

	rows, err := db.Query(`
		SELECT fa.album_id, fa.added_at,
			COALESCE(al.name, '') as name,
			COALESCE(al.normalized_name, '') as normalized_name,
			COALESCE(al.cover_url, '') as cover_url,
			COALESCE(al.cover_path, '') as cover_path,
			COALESCE(al.release_date, '') as release_date,
			COALESCE(al.total_tracks, 0) as total_tracks,
			COALESCE(al.album_type, '') as album_type,
			COALESCE(al.provider, '') as provider,
			COALESCE(a.id, '') as artist_id,
			COALESCE(a.name, '') as artist_name
		FROM favorite_albums fa
		JOIN albums al ON fa.album_id = al.id
		LEFT JOIN artists a ON al.artist_id = a.id
		ORDER BY fa.added_at DESC
	`)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		var albumID, addedAt, name, normalizedName, coverURL, coverPath, releaseDate string
		var totalTracks int64
		var albumType, provider, artistID, artistName string
		if err := rows.Scan(&albumID, &addedAt, &name, &normalizedName, &coverURL, &coverPath,
			&releaseDate, &totalTracks, &albumType, &provider, &artistID, &artistName); err == nil {
			results = append(results, map[string]interface{}{
				"albumId":        albumID,
				"name":           name,
				"normalizedName": normalizedName,
				"coverUrl":       coverURL,
				"coverPath":      coverPath,
				"releaseDate":    releaseDate,
				"totalTracks":    totalTracks,
				"albumType":      albumType,
				"provider":       provider,
				"artistId":       artistID,
				"artistName":     artistName,
				"addedAt":        addedAt,
			})
		}
	}
	if results == nil {
		results = []map[string]interface{}{}
	}
	out, _ := json.Marshal(results)
	return string(out), nil
}

// RemoveFavoriteAlbumV2 removes an album from favorites.
func RemoveFavoriteAlbumV2(albumID string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	_, err = db.Exec("DELETE FROM favorite_albums WHERE album_id = ?", albumID)
	return err
}
