package database

import (
	"database/sql"
	"encoding/json"
	"fmt"
)

func UpdateLocalLibraryAudioMetadata(entryJSON string) error {
	var entry map[string]interface{}
	if err := json.Unmarshal([]byte(entryJSON), &entry); err != nil {
		return err
	}
	id, ok := entry["id"].(string)
	if !ok || id == "" {
		return fmt.Errorf("missing id in entry")
	}

	db, err := Get()
	if err != nil {
		return err
	}

	var metadataID string
	err = db.QueryRow("SELECT metadata_id FROM files WHERE id = ? OR file_path = ?", id, id).Scan(&metadataID)
	if err != nil {
		if err == sql.ErrNoRows {
			return fmt.Errorf("entry not found: %s", id)
		}
		return err
	}

	_, err = db.Exec(`
		UPDATE metadata SET
			track_name=COALESCE(?, track_name),
			artist_name=COALESCE(?, artist_name),
			album_name=COALESCE(?, album_name),
			album_artist=COALESCE(?, album_artist),
			genre=COALESCE(?, genre),
			release_date=COALESCE(?, release_date),
			track_number=COALESCE(?, track_number),
			disc_number=COALESCE(?, disc_number),
			isrc=COALESCE(?, isrc),
			label=COALESCE(?, label),
			duration_ms=COALESCE(?, duration_ms)
		WHERE id = ?`,
		nvl(entry["trackName"]), nvl(entry["artistName"]), nvl(entry["albumName"]),
		nvl(entry["albumArtist"]), nvl(entry["genre"]), nvl(entry["releaseDate"]),
		entry["trackNumber"], entry["discNumber"],
		nvl(entry["isrc"]), nvl(entry["label"]), entry["duration"],
		metadataID)
	return err
}

func UpdateLocalLibraryFileModTimes(entriesJSON string) error {
	var entries map[string]int64
	if err := json.Unmarshal([]byte(entriesJSON), &entries); err != nil {
		return err
	}
	db, err := Get()
	if err != nil {
		return err
	}
	for path, modTime := range entries {
		_, err = db.Exec("UPDATE files SET file_mod_time = ? WHERE file_path = ? AND source = 'local_scan'", modTime, path)
		if err != nil {
			return err
		}
	}
	return nil
}

func ReplaceLocalLibraryConvertedItem(requestJSON string) error {
	var req map[string]interface{}
	if err := json.Unmarshal([]byte(requestJSON), &req); err != nil {
		return err
	}
	id, _ := req["id"].(string)
	newFilePath, _ := req["newFilePath"].(string)
	targetFormat, _ := req["targetFormat"].(string)
	bitrate, _ := req["bitrate"].(float64)
	if id == "" || newFilePath == "" {
		return fmt.Errorf("missing id or newFilePath")
	}

	db, err := Get()
	if err != nil {
		return err
	}
	_, err = db.Exec(`
		UPDATE files SET
			file_path = ?,
			format = ?,
			bitrate = ?
		WHERE (id = ? OR file_path = ?) AND source = 'local_scan'`,
		newFilePath, targetFormat, int(bitrate), id, id)
	return err
}
