package database

import (
	"encoding/json"
	"time"
)

// ============================================================
// V2: Similar Artists
// ============================================================

// AddSimilarArtistV2 adds a similar artist relationship.
func AddSimilarArtistV2(artistID, similarArtistID string, score float64) error {
	db, err := Get()
	if err != nil {
		return err
	}
	now := time.Now().UTC().Format(time.RFC3339)
	_, err = db.Exec(`INSERT INTO similar_artists (artist_id, similar_artist_id, similarity_score, created_at)
		VALUES (?, ?, ?, ?)
		ON CONFLICT(artist_id, similar_artist_id) DO UPDATE SET
			similarity_score = excluded.similarity_score`, artistID, similarArtistID, score, now)
	return err
}

// GetSimilarArtistsV2 returns similar artists as JSON.
func GetSimilarArtistsV2(artistID string) (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	rows, err := db.Query(`
		SELECT sa.similar_artist_id, a.name as artist_name,
			COALESCE(a.image_url,'') as image_url,
			COALESCE(a.image_path,'') as image_path,
			sa.similarity_score
		FROM similar_artists sa
		JOIN artists a ON a.id = sa.similar_artist_id
		WHERE sa.artist_id = ?
		ORDER BY sa.similarity_score DESC, a.name ASC
	`, artistID)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		var similarID, artistName, imageURL, imagePath string
		var score float64
		if err := rows.Scan(&similarID, &artistName, &imageURL, &imagePath, &score); err == nil {
			results = append(results, map[string]interface{}{
				"artistId":   similarID,
				"artistName": artistName,
				"imageUrl":   imageURL,
				"imagePath":  imagePath,
				"score":      score,
			})
		}
	}
	if results == nil {
		results = []map[string]interface{}{}
	}
	out, _ := json.Marshal(results)
	return string(out), nil
}
