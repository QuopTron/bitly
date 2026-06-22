package database

import "encoding/json"

func GetLocalLibraryArtistTracks(artist string) (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	rows, err := db.Query(`
		SELECT `+libraryColumns()+`
		FROM metadata m JOIN files f ON m.id = f.metadata_id
		WHERE m.artist_name = ? AND f.source = 'local_scan'
		ORDER BY m.album_name, m.disc_number, m.track_number`, artist)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		r, err := scanLibraryRow(rows)
		if err == nil {
			results = append(results, r)
		}
	}
	if results == nil {
		results = []map[string]interface{}{}
	}
	out, _ := json.Marshal(results)
	return string(out), nil
}

func GetLocalLibraryAlbumTracks(album, artist string) (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	rows, err := db.Query(`
		SELECT `+libraryColumns()+`
		FROM metadata m JOIN files f ON m.id = f.metadata_id
		WHERE m.album_name = ? AND m.artist_name = ? AND f.source = 'local_scan'
		ORDER BY m.disc_number, m.track_number`, album, artist)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		r, err := scanLibraryRow(rows)
		if err == nil {
			results = append(results, r)
		}
	}
	if results == nil {
		results = []map[string]interface{}{}
	}
	out, _ := json.Marshal(results)
	return string(out), nil
}
