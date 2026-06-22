package database

import (
	"encoding/json"
)

func GetLocalLibraryEntryByID(id string) (string, error) {
	return queryLibraryEntry("m.id = ? AND f.source = 'local_scan'", id)
}

func GetLocalLibraryEntryByIsrc(isrc string) (string, error) {
	return queryLibraryEntry("m.isrc = ? AND f.source = 'local_scan'", isrc)
}

func FindLocalLibraryEntryByTrackAndArtist(track, artist string) (string, error) {
	return queryLibraryEntry("LOWER(m.track_name) = LOWER(?) AND LOWER(m.artist_name) = LOWER(?) AND f.source = 'local_scan'", track, artist)
}

func queryLibraryEntry(whereClause string, args ...interface{}) (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	rows, err := db.Query(`
		SELECT `+libraryColumns()+`
		FROM metadata m JOIN files f ON m.id = f.metadata_id
		WHERE `+whereClause+` LIMIT 1`, args...)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	if rows.Next() {
		r, err := scanLibraryRow(rows)
		if err != nil {
			return "", err
		}
		out, _ := json.Marshal(r)
		return string(out), nil
	}
	return "{}", nil
}
