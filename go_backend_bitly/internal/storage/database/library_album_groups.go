package database

import (
	"database/sql"
	"encoding/json"
)

func GetLocalLibraryAlbumGroups(limit, offset int, searchQuery string) (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}

	where := "f.source = 'local_scan'"
	var args []interface{}
	if searchQuery != "" {
		like := "%" + searchQuery + "%"
		where += " AND (m.album_name LIKE ? OR m.artist_name LIKE ?)"
		args = append(args, like, like)
	}
	args = append(args, limit, offset)

	rows, err := db.Query(`
		SELECT m.album_name, m.artist_name, m.cover_path,
			COUNT(*) as track_count, MAX(f.scanned_at) as latest_scanned
		FROM metadata m JOIN files f ON m.id = f.metadata_id
		WHERE `+where+`
		GROUP BY m.album_name, m.artist_name, m.cover_path
		ORDER BY latest_scanned DESC
		LIMIT ? OFFSET ?`, args...)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var groups []LocalLibraryAlbumGroup
	for rows.Next() {
		var g LocalLibraryAlbumGroup
		var coverPath, latestScanned sql.NullString
		if err := rows.Scan(&g.AlbumName, &g.ArtistName, &coverPath, &g.TrackCount, &latestScanned); err == nil {
			g.CoverPath = coverPath.String
			g.LatestScanned = latestScanned.String
			groups = append(groups, g)
		}
	}
	if groups == nil {
		groups = []LocalLibraryAlbumGroup{}
	}
	out, _ := json.Marshal(groups)
	return string(out), nil
}

func GetLocalLibraryAlbumGroupCount(searchQuery string) (int, error) {
	db, err := Get()
	if err != nil {
		return 0, err
	}

	var count int
	if searchQuery != "" {
		like := "%" + searchQuery + "%"
		err = db.QueryRow(`
			SELECT COUNT(DISTINCT m.album_name || '|' || m.artist_name)
			FROM metadata m JOIN files f ON m.id = f.metadata_id
			WHERE f.source = 'local_scan'
			AND (m.album_name LIKE ? OR m.artist_name LIKE ?)`,
			like, like).Scan(&count)
	} else {
		err = db.QueryRow(`
			SELECT COUNT(DISTINCT m.album_name || '|' || m.artist_name)
			FROM metadata m JOIN files f ON m.id = f.metadata_id
			WHERE f.source = 'local_scan'`).Scan(&count)
	}
	return count, err
}

func GetLocalLibrarySingleTrackCount(searchQuery string) (int, error) {
	db, err := Get()
	if err != nil {
		return 0, err
	}
	where := "f.source = 'local_scan' AND (m.album_name IS NULL OR m.album_name = '')"
	var args []interface{}
	if searchQuery != "" {
		where += " AND (m.track_name LIKE ? OR m.artist_name LIKE ? OR m.album_name LIKE ?)"
		like := "%" + searchQuery + "%"
		args = append(args, like, like, like)
	}
	var count int
	err = db.QueryRow(`
		SELECT COUNT(*) FROM files f
		JOIN metadata m ON f.metadata_id = m.id
		WHERE `+where, args...).Scan(&count)
	return count, err
}
