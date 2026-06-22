package database

import (
	"encoding/json"
)

// ============================================================
// V2: All Artist/Album queries
// ============================================================

// GetAllArtistsV2 returns all known artists as JSON.
func GetAllArtistsV2() (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}

	rows, err := db.Query(`
		SELECT id, name, COALESCE(normalized_name, '') as normalized_name,
			COALESCE(image_url, '') as image_url,
			COALESCE(image_path, '') as image_path,
			COALESCE(provider, '') as provider
		FROM artists ORDER BY name ASC
	`)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		var id, name, normalizedName, imageURL, imagePath, provider string
		if err := rows.Scan(&id, &name, &normalizedName, &imageURL, &imagePath, &provider); err == nil {
			results = append(results, map[string]interface{}{
				"id":             id,
				"name":           name,
				"normalizedName": normalizedName,
				"imageUrl":       imageURL,
				"imagePath":      imagePath,
				"provider":       provider,
			})
		}
	}
	if results == nil {
		results = []map[string]interface{}{}
	}
	out, _ := json.Marshal(results)
	return string(out), nil
}

// GetAllAlbumsV2 returns all known albums as JSON.
func GetAllAlbumsV2() (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}

	rows, err := db.Query(`
		SELECT al.id, al.name,
			COALESCE(al.normalized_name, '') as normalized_name,
			COALESCE(al.cover_url, '') as cover_url,
			COALESCE(al.cover_path, '') as cover_path,
			COALESCE(al.release_date, '') as release_date,
			COALESCE(al.total_tracks, 0) as total_tracks,
			COALESCE(al.album_type, '') as album_type,
			COALESCE(al.provider, '') as provider,
			COALESCE(a.id, '') as artist_id,
			COALESCE(a.name, '') as artist_name
		FROM albums al
		LEFT JOIN artists a ON al.artist_id = a.id
		ORDER BY al.name ASC
	`)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		var albumID, name, normalizedName, coverURL, coverPath, releaseDate string
		var totalTracks int64
		var albumType, provider, artistID, artistName string
		if err := rows.Scan(&albumID, &name, &normalizedName, &coverURL, &coverPath,
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
			})
		}
	}
	if results == nil {
		results = []map[string]interface{}{}
	}
	out, _ := json.Marshal(results)
	return string(out), nil
}

// UpdateArtistImageV2 updates the image_url and image_path for an artist.
func UpdateArtistImageV2(artistID, imageURL, filePath string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	_, err = db.Exec("UPDATE artists SET image_url = ?, image_path = ? WHERE id = ?", imageURL, filePath, artistID)
	return err
}
