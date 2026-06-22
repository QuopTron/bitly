package database

import (
	"database/sql"
	"encoding/json"
	"fmt"
)

// ============================================================
// V2: Track read / update helpers
// ============================================================

// GetTrackV2ByID returns a JSON object with full track details from V2 tables.
func GetTrackV2ByID(trackID string) (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}

	var name, artistName, albumName, isrc, genre, composer, label, copyright string
	var artistID, albumID, coverURL, coverPath, lyricsPath, videoPath, spotifyID, releaseDate sql.NullString
	var duration, trackNumber, totalTracks, discNumber, totalDiscs sql.NullInt64

	err = db.QueryRow(`
		SELECT t.name, a.name as artist_name, COALESCE(al.name,'') as album_name,
			COALESCE(t.isrc,'') as isrc, COALESCE(t.genre,'') as genre,
			COALESCE(t.composer,'') as composer, COALESCE(t.label,'') as label,
			COALESCE(t.copyright,'') as copyright,
			t.artist_id, t.album_id,
			COALESCE(t.cover_url,''), COALESCE(t.cover_path,''),
			COALESCE(t.lyrics_path,''), COALESCE(t.video_path,''),
			COALESCE(t.spotify_id,''),
			COALESCE(t.release_date,''),
			t.duration_ms, t.track_number, t.total_tracks, t.disc_number, t.total_discs
		FROM tracks t
		JOIN artists a ON t.artist_id = a.id
		LEFT JOIN albums al ON t.album_id = al.id
		WHERE t.id = ?
	`, trackID).Scan(
		&name, &artistName, &albumName,
		&isrc, &genre, &composer, &label, &copyright,
		&artistID, &albumID,
		&coverURL, &coverPath, &lyricsPath, &videoPath,
		&spotifyID, &releaseDate,
		&duration, &trackNumber, &totalTracks, &discNumber, &totalDiscs)
	if err != nil {
		return "", err
	}

	var filePath, format string
	var bitDepth, sampleRate int
	db.QueryRow(`
		SELECT COALESCE(file_path,''), COALESCE(format,''),
			COALESCE(bit_depth,0), COALESCE(sample_rate,0)
		FROM files WHERE track_id = ? AND source = 'download' LIMIT 1
	`, trackID).Scan(&filePath, &format, &bitDepth, &sampleRate)

	result := map[string]interface{}{
		"id":          trackID,
		"name":        name,
		"artistName":  artistName,
		"albumName":   albumName,
		"artistId":    artistID.String,
		"albumId":     albumID.String,
		"isrc":        isrc,
		"genre":       genre,
		"composer":    composer,
		"label":       label,
		"copyright":   copyright,
		"coverUrl":    coverURL.String,
		"coverPath":   coverPath.String,
		"lyricsPath":  lyricsPath.String,
		"videoPath":   videoPath.String,
		"spotifyId":   spotifyID.String,
		"releaseDate": releaseDate.String,
		"durationMs":  duration.Int64,
		"trackNumber": trackNumber.Int64,
		"totalTracks": totalTracks.Int64,
		"discNumber":  discNumber.Int64,
		"totalDiscs":  totalDiscs.Int64,
		"filePath":    filePath,
		"format":      format,
		"bitDepth":    bitDepth,
		"sampleRate":  sampleRate,
	}
	out, err := json.Marshal(result)
	if err != nil {
		return "", err
	}
	return string(out), nil
}

// ResolveTrackIDHelper resolves an entry ID to a canonical track ID within a transaction.
func ResolveTrackIDHelper(db *sql.DB, tx *sql.Tx, entryID string) (string, error) {
	var exists int
	err := tx.QueryRow("SELECT COUNT(*) FROM tracks WHERE id = ?", entryID).Scan(&exists)
	if err == nil && exists > 0 {
		return entryID, nil
	}

	var isrc, trackName, artistName string
	err = tx.QueryRow(
		"SELECT COALESCE(isrc,''), COALESCE(track_name,''), COALESCE(artist_name,'') FROM metadata WHERE id = ?",
		entryID).Scan(&isrc, &trackName, &artistName)
	if err != nil {
		return "", fmt.Errorf("metadata lookup: %w", err)
	}

	if canonID := findCanonicalTrackV2WithDB(db, isrc, trackName, artistName); canonID != "" {
		return canonID, nil
	}
	return "", fmt.Errorf("no canonical track found for %s", entryID)
}

// UpdateTrackCoverPathV2 updates the cover_path on a track.
func UpdateTrackCoverPathV2(entryID, coverPath string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	canonID := ResolveTrackID(entryID)
	if canonID == entryID {
		_, err = db.Exec("UPDATE tracks SET cover_path = ? WHERE id = ?", coverPath, entryID)
		return err
	}
	_, err = db.Exec("UPDATE tracks SET cover_path = ? WHERE id = ?", coverPath, canonID)
	return err
}

// UpdateDownloadLyricsPath updates the lyrics_path on the canonical track.
func UpdateDownloadLyricsPath(entryID, path string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	canonID := ResolveTrackID(entryID)
	_, err = db.Exec("UPDATE tracks SET lyrics_path = ? WHERE id = ?", path, canonID)
	return err
}

// UpdateDownloadVideoPath updates the video_path on the canonical track.
func UpdateDownloadVideoPath(entryID, path string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	canonID := ResolveTrackID(entryID)
	_, err = db.Exec("UPDATE tracks SET video_path = ? WHERE id = ?", path, canonID)
	return err
}
