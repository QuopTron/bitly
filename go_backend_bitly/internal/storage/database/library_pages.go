package database

import "encoding/json"

func GetLocalLibraryPage(limit, offset int, searchQuery, sortMode string) (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}

	where := "f.source = 'local_scan'"
	var args []interface{}
	if searchQuery != "" {
		where += " AND (m.track_name LIKE ? OR m.artist_name LIKE ? OR m.album_name LIKE ?)"
		like := "%" + searchQuery + "%"
		args = append(args, like, like, like)
	}

	orderBy := "m.album_name, m.track_number"
	switch sortMode {
	case "title":
		orderBy = "m.track_name"
	case "artist":
		orderBy = "m.artist_name, m.album_name"
	case "latest":
		orderBy = "f.scanned_at DESC"
	}

	args = append(args, limit, offset)
	rows, err := db.Query(`
		SELECT `+libraryColumns()+`
		FROM metadata m JOIN files f ON m.id = f.metadata_id
		WHERE `+where+`
		ORDER BY `+orderBy+`
		LIMIT ? OFFSET ?`, args...)
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

func GetLocalLibraryCount(searchQuery string) (int, error) {
	db, err := Get()
	if err != nil {
		return 0, err
	}

	var count int
	if searchQuery != "" {
		like := "%" + searchQuery + "%"
		err = db.QueryRow(`
			SELECT COUNT(*) FROM files f
			JOIN metadata m ON f.metadata_id = m.id
			WHERE f.source = 'local_scan'
			AND (m.track_name LIKE ? OR m.artist_name LIKE ? OR m.album_name LIKE ?)`,
			like, like, like).Scan(&count)
	} else {
		err = db.QueryRow("SELECT COUNT(*) FROM files WHERE source = 'local_scan'").Scan(&count)
	}
	return count, err
}
