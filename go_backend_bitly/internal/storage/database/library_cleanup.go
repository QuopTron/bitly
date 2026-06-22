package database

import (
	"encoding/json"
	"strings"
)

func CleanupLocalLibraryMissingFiles(pathsJSON string) (int, error) {
	if pathsJSON == "" || pathsJSON == "null" {
		return 0, nil
	}
	var keepPaths []string
	if err := json.Unmarshal([]byte(pathsJSON), &keepPaths); err != nil {
		return 0, err
	}
	if len(keepPaths) == 0 {
		return 0, nil
	}

	db, err := Get()
	if err != nil {
		return 0, err
	}
	placeholders := make([]string, len(keepPaths))
	args := make([]interface{}, len(keepPaths))
	for i, p := range keepPaths {
		placeholders[i] = "?"
		args[i] = p
	}
	res, err := db.Exec(
		"DELETE FROM files WHERE source = 'local_scan' AND file_path NOT IN ("+strings.Join(placeholders, ",")+")",
		args...)
	if err != nil {
		return 0, err
	}
	rowsAffected, _ := res.RowsAffected()
	return int(rowsAffected), nil
}
