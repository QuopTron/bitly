package database

import (
	"database/sql"
	"encoding/json"
	"fmt"
)

func ClearLocalLibrary() error {
	db, err := Get()
	if err != nil {
		return err
	}
	_, err = db.Exec("DELETE FROM files WHERE source = 'local_scan'")
	return err
}

func DeleteLibraryPaths(paths []string) error {
	return WithTx(func(tx *sql.Tx) error {
		stmt, err := tx.Prepare("DELETE FROM files WHERE file_path = ? AND source = 'local_scan'")
		if err != nil {
			return err
		}
		defer stmt.Close()
		for _, path := range paths {
			stmt.Exec(path)
		}
		return nil
	})
}

func DeleteLocalLibraryEntriesByPaths(paths []string) error {
	return DeleteLibraryPaths(paths)
}

func DeleteLocalLibraryEntriesByPathsJSON(requestJSON string) error {
	var paths []string
	if err := json.Unmarshal([]byte(requestJSON), &paths); err != nil {
		return fmt.Errorf("invalid paths JSON: %w", err)
	}
	return DeleteLocalLibraryEntriesByPaths(paths)
}

func DeleteLocalLibraryEntryByID(id string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	_, err = db.Exec("DELETE FROM files WHERE id = ? AND source = 'local_scan'", id)
	return err
}
