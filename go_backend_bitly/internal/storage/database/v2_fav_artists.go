package database

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"
	"time"
)

// ============================================================
// V2: Favorite Artists
// ============================================================

// AddFavoriteArtistV2 adds an artist to favorites.
func AddFavoriteArtistV2(artistID, name, imageURL, provider, addedAt string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	now := addedAt
	if now == "" {
		now = time.Now().UTC().Format(time.RFC3339)
	}
	normalized := strings.ToLower(strings.TrimSpace(name))

	var existingArtistID string
	err = db.QueryRow("SELECT id FROM artists WHERE id = ?", artistID).Scan(&existingArtistID)
	if err == sql.ErrNoRows {
		_, err = db.Exec(`
			INSERT INTO artists (id, name, normalized_name, image_url, provider, created_at)
			VALUES (?, ?, ?, ?, ?, ?)
		`, artistID, name, normalized, imageURL, provider, now)
		if err != nil {
			return fmt.Errorf("insert artist for favorite: %w", err)
		}
	}

	_, err = db.Exec("INSERT OR IGNORE INTO favorite_artists (artist_id, added_at) VALUES (?, ?)", artistID, now)
	if err != nil {
		return fmt.Errorf("add favorite artist: %w", err)
	}
	return nil
}

// GetFavoriteArtistsV2 returns all favorite artists as JSON.
func GetFavoriteArtistsV2() (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}

	rows, err := db.Query(`
		SELECT fa.artist_id, fa.added_at,
			COALESCE(a.name, '') as name,
			COALESCE(a.normalized_name, '') as normalized_name,
			COALESCE(a.image_url, '') as image_url,
			COALESCE(a.image_path, '') as image_path,
			COALESCE(a.provider, '') as provider
		FROM favorite_artists fa
		JOIN artists a ON fa.artist_id = a.id
		ORDER BY fa.added_at DESC
	`)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		var artistID, addedAt, name, normalizedName, imageURL, imagePath, provider string
		if err := rows.Scan(&artistID, &addedAt, &name, &normalizedName, &imageURL, &imagePath, &provider); err == nil {
			results = append(results, map[string]interface{}{
				"artistId":       artistID,
				"name":           name,
				"normalizedName": normalizedName,
				"imageUrl":       imageURL,
				"imagePath":      imagePath,
				"provider":       provider,
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

// RemoveFavoriteArtistV2 removes an artist from favorites.
func RemoveFavoriteArtistV2(artistID string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	_, err = db.Exec("DELETE FROM favorite_artists WHERE artist_id = ?", artistID)
	return err
}
