package database

import "encoding/json"

func GetDownloadHistoryFilePaths() (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	rows, err := db.Query("SELECT file_path FROM files WHERE source = 'download'")
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var paths []string
	for rows.Next() {
		var p string
		if err := rows.Scan(&p); err == nil {
			paths = append(paths, p)
		}
	}
	if paths == nil {
		paths = []string{}
	}
	out, _ := json.Marshal(paths)
	return string(out), nil
}

func GetDownloadAlbumTracks(album, artist string) (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	rows, err := db.Query(`
		SELECT `+historyColumns()+`
		FROM metadata m JOIN files f ON m.id = f.metadata_id
		WHERE m.album_name = ? AND m.album_artist = ? AND f.source = 'download'
		ORDER BY m.disc_number, m.track_number`, album, artist)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var entries []DownloadHistoryEntry
	for rows.Next() {
		e, err := scanHistoryEntry(rows)
		if err == nil {
			entries = append(entries, e)
		}
	}
	if entries == nil {
		entries = []DownloadHistoryEntry{}
	}
	out, _ := json.Marshal(entries)
	return string(out), nil
}

func GetDownloadArtistTracks(artist string) (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	rows, err := db.Query(`
		SELECT `+historyColumns()+`
		FROM metadata m JOIN files f ON m.id = f.metadata_id
		WHERE m.artist_name = ? AND f.source = 'download'
		ORDER BY m.album_name, m.disc_number, m.track_number`, artist)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var entries []DownloadHistoryEntry
	for rows.Next() {
		e, err := scanHistoryEntry(rows)
		if err == nil {
			entries = append(entries, e)
		}
	}
	if entries == nil {
		entries = []DownloadHistoryEntry{}
	}
	out, _ := json.Marshal(entries)
	return string(out), nil
}
