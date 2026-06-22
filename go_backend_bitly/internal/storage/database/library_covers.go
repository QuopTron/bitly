package database

import "encoding/json"

func GetLocalLibraryCoverPaths() (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	rows, err := db.Query("SELECT cover_path FROM metadata WHERE cover_path IS NOT NULL")
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

func GetLocalLibraryEntriesWithPathsPage(limit, offset int) (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	rows, err := db.Query("SELECT file_path FROM files WHERE source = 'local_scan' LIMIT ? OFFSET ?", limit, offset)
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
