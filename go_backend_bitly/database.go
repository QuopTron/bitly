package gobackend

import (
	"database/sql"
	_ "embed"
	"encoding/json"
	"fmt"
	"strings"
	"sync"
	"time"

	_ "github.com/ncruces/go-sqlite3/driver"
)

//go:embed schema.sql
var schemaSQL string

var (
	masterDB   *sql.DB
	masterDBMu sync.RWMutex
	dbPath     string
)

func InitMasterDatabase(path string) error {
	masterDBMu.Lock()
	defer masterDBMu.Unlock()

	if masterDB != nil {
		masterDB.Close()
	}

	db, err := sql.Open("sqlite3", path)
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}

	// Optimize for performance
	if _, err := db.Exec("PRAGMA journal_mode=WAL"); err != nil {
		GoLog("[DB] WAL pragma warning: %v", err)
	}
	if _, err := db.Exec("PRAGMA synchronous=NORMAL"); err != nil {
		GoLog("[DB] synchronous pragma warning: %v", err)
	}
	if _, err := db.Exec("PRAGMA cache_size=-64000"); err != nil {
		GoLog("[DB] cache_size pragma warning: %v", err)
	}
	if _, err := db.Exec("PRAGMA busy_timeout=5000"); err != nil {
		GoLog("[DB] busy_timeout pragma warning: %v", err)
	}
	// Extra safety for concurrent access
	if _, err := db.Exec("PRAGMA locking_mode=NORMAL"); err != nil {
		GoLog("[DB] locking_mode pragma warning: %v", err)
	}

	// Execute schema to create tables if they don't exist
	if _, err := db.Exec(schemaSQL); err != nil {
		db.Close()
		return fmt.Errorf("failed to execute schema: %w", err)
	}

	masterDB = db
	dbPath = path
	return nil
}

func GetMasterDB() (*sql.DB, error) {
	masterDBMu.RLock()
	defer masterDBMu.RUnlock()
	if masterDB == nil {
		return nil, fmt.Errorf("database not initialized")
	}
	return masterDB, nil
}

func withDB(fn func(*sql.DB) error) error {
	masterDBMu.RLock()
	db := masterDB
	masterDBMu.RUnlock()
	if db == nil {
		return fmt.Errorf("database not initialized")
	}
	return fn(db)
}

func withDBResult[T any](fn func(*sql.DB) (T, error)) (T, error) {
	masterDBMu.RLock()
	db := masterDB
	masterDBMu.RUnlock()
	if db == nil {
		var zero T
		return zero, fmt.Errorf("database not initialized")
	}
	return fn(db)
}

func UpsertLibraryTrack(item LibraryScanResult) error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}

	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// 1. Insert/Update Metadata
	_, err = tx.Exec(`
		INSERT INTO metadata (
			id, track_name, artist_name, album_name, album_artist,
			isrc, track_number, total_tracks, disc_number, total_discs,
			duration_ms, release_date, genre, composer, label, copyright, cover_path
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(id) DO UPDATE SET
			track_name=excluded.track_name,
			artist_name=excluded.artist_name,
			album_name=excluded.album_name,
			album_artist=excluded.album_artist,
			isrc=excluded.isrc,
			track_number=excluded.track_number,
			total_tracks=excluded.total_tracks,
			disc_number=excluded.disc_number,
			total_discs=excluded.total_discs,
			duration_ms=excluded.duration_ms,
			release_date=excluded.release_date,
			genre=excluded.genre,
			composer=excluded.composer,
			label=excluded.label,
			copyright=excluded.copyright,
			cover_path=COALESCE(excluded.cover_path, metadata.cover_path)
	`,
		item.ID, item.TrackName, item.ArtistName, item.AlbumName, item.AlbumArtist,
		item.ISRC, item.TrackNumber, item.TotalTracks, item.DiscNumber, item.TotalDiscs,
		item.Duration, item.ReleaseDate, item.Genre, item.Composer, item.Label, item.Copyright, item.CoverPath,
	)
	if err != nil {
		return err
	}

	// 2. Insert/Update File entry
	_, err = tx.Exec(`
		INSERT INTO files (
			id, metadata_id, file_path, source, format, bitrate, bit_depth, sample_rate, file_mod_time, scanned_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(file_path) DO UPDATE SET
			metadata_id=excluded.metadata_id,
			format=excluded.format,
			bitrate=excluded.bitrate,
			bit_depth=excluded.bit_depth,
			sample_rate=excluded.sample_rate,
			file_mod_time=excluded.file_mod_time,
			scanned_at=excluded.scanned_at
	`,
		item.ID, item.ID, item.FilePath, "local_scan", item.Format, item.Bitrate, item.BitDepth, item.SampleRate, item.FileModTime, item.ScannedAt,
	)
	if err != nil {
		return err
	}

	return tx.Commit()
}

func UpsertLibraryBatch(items []LibraryScanResult) error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}

	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	stmtMeta, err := tx.Prepare(`
		INSERT INTO metadata (id, track_name, artist_name, album_name, album_artist, isrc, track_number, total_tracks, disc_number, total_discs, duration_ms, release_date, genre, composer, label, copyright, cover_path)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(id) DO UPDATE SET track_name=excluded.track_name, artist_name=excluded.artist_name, album_name=excluded.album_name, album_artist=excluded.album_artist, isrc=excluded.isrc, track_number=excluded.track_number, total_tracks=excluded.total_tracks, disc_number=excluded.disc_number, total_discs=excluded.total_discs, duration_ms=excluded.duration_ms, release_date=excluded.release_date, genre=excluded.genre, composer=excluded.composer, label=excluded.label, copyright=excluded.copyright, cover_path=COALESCE(excluded.cover_path, metadata.cover_path)
	`)
	if err != nil {
		return err
	}
	defer stmtMeta.Close()

	stmtFile, err := tx.Prepare(`
		INSERT INTO files (id, metadata_id, file_path, source, format, bitrate, bit_depth, sample_rate, file_mod_time, scanned_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(file_path) DO UPDATE SET metadata_id=excluded.metadata_id, format=excluded.format, bitrate=excluded.bitrate, bit_depth=excluded.bit_depth, sample_rate=excluded.sample_rate, file_mod_time=excluded.file_mod_time, scanned_at=excluded.scanned_at
	`)
	if err != nil {
		return err
	}
	defer stmtFile.Close()

	for _, item := range items {
		if _, err := stmtMeta.Exec(item.ID, item.TrackName, item.ArtistName, item.AlbumName, item.AlbumArtist, item.ISRC, item.TrackNumber, item.TotalTracks, item.DiscNumber, item.TotalDiscs, item.Duration, item.ReleaseDate, item.Genre, item.Composer, item.Label, item.Copyright, item.CoverPath); err != nil {
			tx.Rollback()
			return fmt.Errorf("batch meta insert failed: %w", err)
		}
		if _, err := stmtFile.Exec(item.ID, item.ID, item.FilePath, "local_scan", item.Format, item.Bitrate, item.BitDepth, item.SampleRate, item.FileModTime, item.ScannedAt); err != nil {
			tx.Rollback()
			return fmt.Errorf("batch file insert failed: %w", err)
		}
	}

	return tx.Commit()
}

func SearchLibrary(query string, limit int) ([]LibraryScanResult, error) {
	db, err := GetMasterDB()
	if err != nil {
		return nil, err
	}

	rows, err := db.Query(`
		SELECT f.id, m.track_name, m.artist_name, m.album_name, m.album_artist, f.file_path, m.cover_path, f.scanned_at, f.file_mod_time, m.isrc, m.track_number, m.total_tracks, m.disc_number, m.total_discs, m.duration_ms, m.release_date, f.bit_depth, f.sample_rate, f.bitrate, m.genre, m.composer, m.label, m.copyright, f.format
		FROM files f
		JOIN metadata m ON f.metadata_id = m.id
		WHERE (m.track_name LIKE ? OR m.artist_name LIKE ? OR m.album_name LIKE ?) AND f.source = 'local_scan'
		LIMIT ?
	`, "%"+query+"%", "%"+query+"%", "%"+query+"%", limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []LibraryScanResult
	for rows.Next() {
		var r LibraryScanResult
		err := rows.Scan(&r.ID, &r.TrackName, &r.ArtistName, &r.AlbumName, &r.AlbumArtist, &r.FilePath, &r.CoverPath, &r.ScannedAt, &r.FileModTime, &r.ISRC, &r.TrackNumber, &r.TotalTracks, &r.DiscNumber, &r.TotalDiscs, &r.Duration, &r.ReleaseDate, &r.BitDepth, &r.SampleRate, &r.Bitrate, &r.Genre, &r.Composer, &r.Label, &r.Copyright, &r.Format)
		if err == nil {
			results = append(results, r)
		}
	}
	return results, nil
}

func GetExistingModTimes() (map[string]int64, error) {
	db, err := GetMasterDB()
	if err != nil {
		return nil, err
	}

	rows, err := db.Query("SELECT file_path, file_mod_time FROM files WHERE source = 'local_scan'")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	res := make(map[string]int64)
	for rows.Next() {
		var path string
		var mod int64
		if err := rows.Scan(&path, &mod); err == nil {
			res[path] = mod
		}
	}
	return res, nil
}

func DeleteLibraryPaths(paths []string) error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}

	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	stmt, err := tx.Prepare("DELETE FROM files WHERE file_path = ? AND source = 'local_scan'")
	if err != nil {
		return err
	}
	defer stmt.Close()

	for _, path := range paths {
		if _, err := stmt.Exec(path); err != nil {
			tx.Rollback()
			return fmt.Errorf("delete path %s failed: %w", path, err)
		}
	}

	return tx.Commit()
}

// --- Download History Operations (managed by Go to avoid DB contention with Dart) ---

type DownloadHistoryEntry struct {
	ID             string `json:"id"`
	TrackName      string `json:"trackName"`
	ArtistName     string `json:"artistName"`
	AlbumName      string `json:"albumName"`
	AlbumArtist    string `json:"albumArtist,omitempty"`
	FilePath       string `json:"filePath"`
	CoverURL       string `json:"coverUrl,omitempty"`
	CoverPath      string `json:"coverPath,omitempty"`
	ISRC           string `json:"isrc,omitempty"`
	Duration       int    `json:"duration,omitempty"`
	TrackNumber    int    `json:"trackNumber,omitempty"`
	TotalTracks    int    `json:"totalTracks,omitempty"`
	DiscNumber     int    `json:"discNumber,omitempty"`
	TotalDiscs     int    `json:"totalDiscs,omitempty"`
	ReleaseDate    string `json:"releaseDate,omitempty"`
	Genre          string `json:"genre,omitempty"`
	Composer       string `json:"composer,omitempty"`
	Label          string `json:"label,omitempty"`
	Copyright      string `json:"copyright,omitempty"`
	Quality        string `json:"quality,omitempty"`
	BitDepth       int    `json:"bitDepth,omitempty"`
	SampleRate     int    `json:"sampleRate,omitempty"`
	Bitrate        int    `json:"bitrate,omitempty"`
	SpotifyID      string `json:"spotifyId,omitempty"`
	DownloadedAt   string `json:"downloadedAt"`
	Service        string `json:"service,omitempty"`
	StorageMode    string `json:"storageMode,omitempty"`
	SAFFileName    string `json:"safFileName,omitempty"`
	SafRelativeDir string `json:"safRelativeDir,omitempty"`
	VideoFilePath  string `json:"videoFilePath,omitempty"`
	Format         string `json:"format,omitempty"`
}

func historyColumns() string {
	return `m.id, m.track_name, m.artist_name, m.album_name, m.album_artist,
		m.cover_url, m.cover_path, m.isrc, m.duration_ms, m.track_number,
		m.total_tracks, m.disc_number, m.total_discs, m.release_date,
		m.genre, m.composer, m.label, m.copyright, m.spotify_id,
		f.file_path, f.format, f.bitrate, f.bit_depth, f.sample_rate,
		f.downloaded_at, f.saf_file_name, f.source,
		f.bit_depth as eff_bit_depth,
		f.sample_rate as eff_sample_rate`
}

func scanHistoryEntry(row *sql.Rows) (DownloadHistoryEntry, error) {
	var e DownloadHistoryEntry
	var coverURL, coverPath, isrc, releaseDate, genre, composer, label, copyright, spotifyID sql.NullString
	var albumArtist, format, safFileName, source sql.NullString
	var duration, trackNumber, totalTracks, discNumber, totalDiscs sql.NullInt64
	var bitrate, bitDepth, sampleRate sql.NullInt64
	var downloadedAt sql.NullString

	err := row.Scan(
		&e.ID, &e.TrackName, &e.ArtistName, &e.AlbumName, &albumArtist,
		&coverURL, &coverPath, &isrc, &duration, &trackNumber,
		&totalTracks, &discNumber, &totalDiscs, &releaseDate,
		&genre, &composer, &label, &copyright, &spotifyID,
		&e.FilePath, &format, &bitrate, &bitDepth, &sampleRate,
		&downloadedAt, &safFileName, &source,
	)
	if err != nil {
		return e, err
	}
	e.CoverURL = coverURL.String
	e.CoverPath = coverPath.String
	e.ISRC = isrc.String
	e.ReleaseDate = releaseDate.String
	e.Genre = genre.String
	e.Composer = composer.String
	e.Label = label.String
	e.Copyright = copyright.String
	e.SpotifyID = spotifyID.String
	e.AlbumArtist = albumArtist.String
	e.Format = format.String
	e.SAFFileName = safFileName.String
	if duration.Valid {
		e.Duration = int(duration.Int64)
	}
	if trackNumber.Valid {
		e.TrackNumber = int(trackNumber.Int64)
	}
	if totalTracks.Valid {
		e.TotalTracks = int(totalTracks.Int64)
	}
	if discNumber.Valid {
		e.DiscNumber = int(discNumber.Int64)
	}
	if totalDiscs.Valid {
		e.TotalDiscs = int(totalDiscs.Int64)
	}
	if bitrate.Valid {
		e.Bitrate = int(bitrate.Int64)
	}
	if bitDepth.Valid {
		e.BitDepth = int(bitDepth.Int64)
	}
	if sampleRate.Valid {
		e.SampleRate = int(sampleRate.Int64)
	}
	e.DownloadedAt = downloadedAt.String
	return e, nil
}

func UpsertDownloadEntry(entry DownloadHistoryEntry) error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	_, err = tx.Exec(`
		INSERT INTO metadata (id, track_name, artist_name, album_name, album_artist,
			isrc, duration_ms, track_number, total_tracks, disc_number, total_discs,
			release_date, genre, composer, label, copyright, spotify_id, cover_url, cover_path)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(id) DO UPDATE SET
			track_name=excluded.track_name, artist_name=excluded.artist_name,
			album_name=excluded.album_name, album_artist=excluded.album_artist,
			isrc=excluded.isrc, duration_ms=excluded.duration_ms,
			track_number=excluded.track_number, total_tracks=excluded.total_tracks,
			disc_number=excluded.disc_number, total_discs=excluded.total_discs,
			release_date=excluded.release_date, genre=excluded.genre,
			composer=excluded.composer, label=excluded.label, copyright=excluded.copyright,
			spotify_id=COALESCE(excluded.spotify_id, metadata.spotify_id),
			cover_url=COALESCE(excluded.cover_url, metadata.cover_url),
			cover_path=COALESCE(excluded.cover_path, metadata.cover_path)`,
		entry.ID, entry.TrackName, entry.ArtistName, entry.AlbumName, entry.AlbumArtist,
		entry.ISRC, entry.Duration, entry.TrackNumber, entry.TotalTracks,
		entry.DiscNumber, entry.TotalDiscs, entry.ReleaseDate, entry.Genre,
		entry.Composer, entry.Label, entry.Copyright, entry.SpotifyID,
		entry.CoverURL, entry.CoverPath)
	if err != nil {
		return err
	}

	_, err = tx.Exec(`
		INSERT INTO files (id, metadata_id, file_path, source, format, bitrate, bit_depth, sample_rate, downloaded_at, saf_file_name)
		VALUES (?, ?, ?, 'download', ?, ?, ?, ?, ?, ?)
		ON CONFLICT(file_path) DO UPDATE SET
			metadata_id=excluded.metadata_id, format=excluded.format,
			bitrate=excluded.bitrate, bit_depth=excluded.bit_depth,
			sample_rate=excluded.sample_rate,
			downloaded_at=excluded.downloaded_at, saf_file_name=excluded.saf_file_name`,
		entry.ID, entry.ID, entry.FilePath, entry.Format, entry.Bitrate,
		entry.BitDepth, entry.SampleRate, entry.DownloadedAt, entry.SAFFileName)
	if err != nil {
		return err
	}

	return tx.Commit()
}

func ClearDownloadHistory() error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	_, err = db.Exec("DELETE FROM files WHERE source = 'download'")
	return err
}

func DeleteDownloadEntriesByIDs(ids []string) error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	for _, id := range ids {
		tx.Exec("DELETE FROM files WHERE id = ? AND source = 'download'", id)
		tx.Exec("DELETE FROM metadata WHERE id = ?", id)
	}
	return tx.Commit()
}

func DeleteDownloadEntriesByPaths(paths []string) error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	for _, path := range paths {
		tx.Exec("DELETE FROM files WHERE file_path = ? AND source = 'download'", path)
	}
	return tx.Commit()
}

func DeleteDownloadEntriesByTrackMatch(trackName, artistName string) error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	rows, err := db.Query(
		"SELECT id FROM metadata WHERE LOWER(track_name) = LOWER(?) AND LOWER(artist_name) = LOWER(?)",
		trackName, artistName)
	if err != nil {
		return err
	}
	defer rows.Close()

	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err == nil {
			ids = append(ids, id)
		}
	}
	if len(ids) == 0 {
		return nil
	}
	return DeleteDownloadEntriesByIDs(ids)
}

func GetDownloadHistory(limit, offset int) (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	rows, err := db.Query(`
		SELECT `+historyColumns()+`
		FROM metadata m JOIN files f ON m.id = f.metadata_id
		WHERE f.source = 'download'
		ORDER BY f.downloaded_at DESC
		LIMIT ? OFFSET ?`, limit, offset)
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

func GetDownloadHistoryCount() (int, error) {
	db, err := GetMasterDB()
	if err != nil {
		return 0, err
	}
	var count int
	err = db.QueryRow("SELECT COUNT(*) FROM files WHERE source = 'download'").Scan(&count)
	return count, err
}

type DownloadGroupedCounts struct {
	AlbumCount       int `json:"albumCount"`
	SingleTrackCount int `json:"singleTrackCount"`
}

func GetDownloadHistoryGroupedCounts() (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	rows, err := db.Query(`
		SELECT m.album_name, m.album_artist, COUNT(*) as cnt
		FROM metadata m JOIN files f ON m.id = f.metadata_id
		WHERE f.source = 'download'
		GROUP BY m.album_name, m.album_artist`)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var counts DownloadGroupedCounts
	for rows.Next() {
		var album, artist sql.NullString
		var cnt int
		if err := rows.Scan(&album, &artist, &cnt); err == nil {
			if album.Valid && album.String != "" {
				counts.AlbumCount++
			} else {
				counts.SingleTrackCount++
			}
		}
	}
	out, _ := json.Marshal(counts)
	return string(out), nil
}

func GetDownloadEntryByID(id string) (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	row := db.QueryRow(`
		SELECT `+historyColumns()+`
		FROM metadata m JOIN files f ON m.id = f.metadata_id
		WHERE m.id = ? AND f.source = 'download'`, id)
	return scanSingleHistoryEntry(row)
}

func GetDownloadEntryBySpotifyID(sid string) (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	row := db.QueryRow(`
		SELECT `+historyColumns()+`
		FROM metadata m JOIN files f ON m.id = f.metadata_id
		WHERE m.spotify_id = ? AND f.source = 'download'`, sid)
	return scanSingleHistoryEntry(row)
}

func GetDownloadEntryByISRC(isrc string) (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	row := db.QueryRow(`
		SELECT `+historyColumns()+`
		FROM metadata m JOIN files f ON m.id = f.metadata_id
		WHERE m.isrc = ? AND f.source = 'download'`, isrc)
	return scanSingleHistoryEntry(row)
}

func FindDownloadEntryByTrackAndArtist(track, artist string) (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	row := db.QueryRow(`
		SELECT `+historyColumns()+`
		FROM metadata m JOIN files f ON m.id = f.metadata_id
		WHERE LOWER(m.track_name) = LOWER(?) AND LOWER(m.artist_name) = LOWER(?) AND f.source = 'download'
		LIMIT 1`, track, artist)
	return scanSingleHistoryEntry(row)
}

func scanSingleHistoryEntry(row *sql.Row) (string, error) {
	var e DownloadHistoryEntry
	var coverURL, coverPath, isrc, releaseDate, genre, composer, label, copyright, spotifyID sql.NullString
	var albumArtist, format, safFileName, source sql.NullString
	var duration, trackNumber, totalTracks, discNumber, totalDiscs sql.NullInt64
	var bitrate, bitDepth, sampleRate sql.NullInt64
	var downloadedAt sql.NullString

	err := row.Scan(
		&e.ID, &e.TrackName, &e.ArtistName, &e.AlbumName, &albumArtist,
		&coverURL, &coverPath, &isrc, &duration, &trackNumber,
		&totalTracks, &discNumber, &totalDiscs, &releaseDate,
		&genre, &composer, &label, &copyright, &spotifyID,
		&e.FilePath, &format, &bitrate, &bitDepth, &sampleRate,
		&downloadedAt, &safFileName, &source,
	)
	if err != nil {
		return "", err
	}
	e.CoverURL = coverURL.String
	e.CoverPath = coverPath.String
	e.ISRC = isrc.String
	e.ReleaseDate = releaseDate.String
	e.Genre = genre.String
	e.Composer = composer.String
	e.Label = label.String
	e.Copyright = copyright.String
	e.SpotifyID = spotifyID.String
	e.AlbumArtist = albumArtist.String
	e.Format = format.String
	e.SAFFileName = safFileName.String
	if duration.Valid {
		e.Duration = int(duration.Int64)
	}
	if trackNumber.Valid {
		e.TrackNumber = int(trackNumber.Int64)
	}
	if totalTracks.Valid {
		e.TotalTracks = int(totalTracks.Int64)
	}
	if discNumber.Valid {
		e.DiscNumber = int(discNumber.Int64)
	}
	if totalDiscs.Valid {
		e.TotalDiscs = int(totalDiscs.Int64)
	}
	if bitrate.Valid {
		e.Bitrate = int(bitrate.Int64)
	}
	if bitDepth.Valid {
		e.BitDepth = int(bitDepth.Int64)
	}
	if sampleRate.Valid {
		e.SampleRate = int(sampleRate.Int64)
	}
	e.DownloadedAt = downloadedAt.String

	out, _ := json.Marshal(e)
	return string(out), nil
}

func UpdateDownloadFilePath(id, filePath string) error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	_, err = db.Exec("UPDATE files SET file_path = ? WHERE id = ? AND source = 'download'", filePath, id)
	return err
}

func UpdateDownloadAudioMetadata(entry DownloadHistoryEntry) error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	_, err = db.Exec(`
		UPDATE metadata SET
			track_name=?, artist_name=?, album_name=?, album_artist=?,
			genre=?, release_date=?, track_number=?, disc_number=?,
			isrc=?, label=?, duration_ms=?
		WHERE id = ?`,
		entry.TrackName, entry.ArtistName, entry.AlbumName, entry.AlbumArtist,
		entry.Genre, entry.ReleaseDate, entry.TrackNumber, entry.DiscNumber,
		entry.ISRC, entry.Label, entry.Duration, entry.ID)
	return err
}

func GetDownloadHistoryFilePaths() (string, error) {
	db, err := GetMasterDB()
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

type TrackKeyRequest struct {
	SpotifyID  string `json:"spotifyId,omitempty"`
	ISRC       string `json:"isrc,omitempty"`
	TrackName  string `json:"trackName,omitempty"`
	ArtistName string `json:"artistName,omitempty"`
}

func ExistingDownloadTrackKeys(requestsJSON string) (string, error) {
	var requests []TrackKeyRequest
	if err := json.Unmarshal([]byte(requestsJSON), &requests); err != nil {
		return "", err
	}
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}

	keys := make(map[string]bool)
	for _, req := range requests {
		var count int
		var qerr error
		if req.SpotifyID != "" {
			qerr = db.QueryRow("SELECT COUNT(*) FROM metadata WHERE spotify_id = ?", req.SpotifyID).Scan(&count)
		} else if req.ISRC != "" {
			qerr = db.QueryRow("SELECT COUNT(*) FROM metadata WHERE isrc = ?", req.ISRC).Scan(&count)
		} else if req.TrackName != "" {
			qerr = db.QueryRow("SELECT COUNT(*) FROM metadata WHERE LOWER(track_name) = LOWER(?) AND LOWER(artist_name) = LOWER(?)",
				req.TrackName, req.ArtistName).Scan(&count)
		}
		if qerr != nil {
			GoLog("[DB] ExistingDownloadTrackKeys query warning: %v", qerr)
		}
		key := fmt.Sprintf("%s|%s", req.TrackName, req.ArtistName)
		keys[key] = count > 0
	}
	out, _ := json.Marshal(keys)
	return string(out), nil
}

type AlbumTracksQuery struct {
	Album  string `json:"album"`
	Artist string `json:"artist"`
}

func GetDownloadAlbumTracks(album, artist string) (string, error) {
	db, err := GetMasterDB()
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
	db, err := GetMasterDB()
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

// --- Library Database Operations (managed by Go) ---

func UpsertLocalLibraryEntry(entry DownloadHistoryEntry) error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	_, err = tx.Exec(`
		INSERT INTO metadata (id, track_name, artist_name, album_name, album_artist,
			isrc, duration_ms, track_number, total_tracks, disc_number, total_discs,
			release_date, genre, composer, label, copyright, cover_path)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(id) DO UPDATE SET
			track_name=excluded.track_name, artist_name=excluded.artist_name,
			album_name=excluded.album_name, album_artist=excluded.album_artist,
			isrc=excluded.isrc, duration_ms=excluded.duration_ms,
			track_number=excluded.track_number, total_tracks=excluded.total_tracks,
			disc_number=excluded.disc_number, total_discs=excluded.total_discs,
			release_date=excluded.release_date, genre=excluded.genre,
			composer=excluded.composer, label=excluded.label, copyright=excluded.copyright,
			cover_path=COALESCE(excluded.cover_path, metadata.cover_path)`,
		entry.ID, entry.TrackName, entry.ArtistName, entry.AlbumName, entry.AlbumArtist,
		entry.ISRC, entry.Duration, entry.TrackNumber, entry.TotalTracks,
		entry.DiscNumber, entry.TotalDiscs, entry.ReleaseDate, entry.Genre,
		entry.Composer, entry.Label, entry.Copyright, entry.CoverPath)
	if err != nil {
		return err
	}

	_, err = tx.Exec(`
		INSERT INTO files (id, metadata_id, file_path, source, format, bitrate, bit_depth, sample_rate)
		VALUES (?, ?, ?, 'local_scan', ?, ?, ?, ?)
		ON CONFLICT(file_path) DO UPDATE SET
			metadata_id=excluded.metadata_id, format=excluded.format,
			bitrate=excluded.bitrate, bit_depth=excluded.bit_depth,
			sample_rate=excluded.sample_rate`,
		entry.ID, entry.ID, entry.FilePath, entry.Format, entry.Bitrate,
		entry.BitDepth, entry.SampleRate)
	if err != nil {
		return err
	}

	return tx.Commit()
}

func ClearLocalLibrary() error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	_, err = db.Exec("DELETE FROM files WHERE source = 'local_scan'")
	return err
}

func DeleteLocalLibraryEntriesByPaths(paths []string) error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	stmt, err := tx.Prepare("DELETE FROM files WHERE file_path = ? AND source = 'local_scan'")
	if err != nil {
		return err
	}
	defer stmt.Close()

	for _, path := range paths {
		stmt.Exec(path)
	}
	return tx.Commit()
}

// --- Favorites (Likes) ---

func UpsertFavorite(itemJSON string) error {
	var item map[string]interface{}
	if err := json.Unmarshal([]byte(itemJSON), &item); err != nil {
		return err
	}
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	_, err = db.Exec(`
		INSERT INTO favorites (item_id, type, name, secondary_name, cover_url, added_at, item_json, cover_path, audio_path, match_key, codec, bit_depth, sample_rate)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(item_id) DO UPDATE SET
			type=excluded.type, name=excluded.name, secondary_name=excluded.secondary_name,
			cover_url=excluded.cover_url, added_at=excluded.added_at,
			item_json=excluded.item_json, cover_path=excluded.cover_path,
			audio_path=excluded.audio_path, match_key=excluded.match_key,
			codec=excluded.codec, bit_depth=excluded.bit_depth, sample_rate=excluded.sample_rate`,
		nvl(item["item_id"]), nvl(item["type"]), nvl(item["name"]), nvl(item["secondary_name"]),
		nvl(item["cover_url"]), nvl(item["added_at"]), nvl(item["item_json"]),
		nvl(item["cover_path"]), nvl(item["audio_path"]), nvl(item["match_key"]),
		nvl(item["codec"]), nvl(item["bit_depth"]), nvl(item["sample_rate"]))
	return err
}

func DeleteFavorite(itemID string) error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	_, err = db.Exec("DELETE FROM favorites WHERE item_id = ?", itemID)
	return err
}

func GetAllFavorites(typeFilter string) (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	var rows *sql.Rows
	if typeFilter != "" {
		rows, err = db.Query("SELECT * FROM favorites WHERE type = ? ORDER BY added_at DESC", typeFilter)
	} else {
		rows, err = db.Query("SELECT * FROM favorites ORDER BY added_at DESC")
	}
	if err != nil {
		return "", err
	}
	defer rows.Close()

	cols, _ := rows.Columns()
	var results []map[string]interface{}
	for rows.Next() {
		vals := make([]interface{}, len(cols))
		valPtrs := make([]interface{}, len(cols))
		for i := range vals {
			valPtrs[i] = &vals[i]
		}
		rows.Scan(valPtrs...)
		row := make(map[string]interface{})
		for i, col := range cols {
			if vals[i] != nil {
				switch v := vals[i].(type) {
				case []byte:
					row[col] = string(v)
				default:
					row[col] = v
				}
			}
		}
		results = append(results, row)
	}
	if results == nil {
		results = []map[string]interface{}{}
	}
	out, _ := json.Marshal(results)
	return string(out), nil
}

// --- Local Library Query Operations (managed by Go to avoid DB contention) ---

func libraryColumns() string {
	return `m.id, m.track_name, m.artist_name, m.album_name, m.album_artist,
		m.isrc, m.track_number, m.total_tracks, m.disc_number, m.total_discs,
		m.duration_ms, m.release_date, m.genre, m.composer, m.label, m.copyright,
		m.cover_path, f.file_path, f.format, f.bitrate, f.bit_depth, f.sample_rate,
		f.file_mod_time, f.scanned_at`
}

func scanLibraryRow(row *sql.Rows) (map[string]interface{}, error) {
	var id, trackName, artistName, albumName, filePath, scannedAt sql.NullString
	var albumArtist, coverPath, isrc, releaseDate, genre, composer, label, copyright, format sql.NullString
	var trackNumber, totalTracks, discNumber, totalDiscs, duration, bitDepth, sampleRate, bitrate, fileModTime sql.NullInt64

	err := row.Scan(
		&id, &trackName, &artistName, &albumName, &albumArtist,
		&isrc, &trackNumber, &totalTracks, &discNumber, &totalDiscs,
		&duration, &releaseDate, &genre, &composer, &label, &copyright,
		&coverPath, &filePath, &format, &bitrate, &bitDepth, &sampleRate,
		&fileModTime, &scannedAt)
	if err != nil {
		return nil, err
	}

	result := map[string]interface{}{
		"id":          id.String,
		"trackName":   trackName.String,
		"artistName":  artistName.String,
		"albumName":   albumName.String,
		"albumArtist": albumArtist.String,
		"filePath":    filePath.String,
		"coverPath":   coverPath.String,
		"scannedAt":   scannedAt.String,
		"fileModTime": fileModTime.Int64,
		"isrc":        isrc.String,
		"trackNumber": trackNumber.Int64,
		"totalTracks": totalTracks.Int64,
		"discNumber":  discNumber.Int64,
		"totalDiscs":  totalDiscs.Int64,
		"duration":    duration.Int64,
		"releaseDate": releaseDate.String,
		"bitDepth":    bitDepth.Int64,
		"sampleRate":  sampleRate.Int64,
		"bitrate":     bitrate.Int64,
		"genre":       genre.String,
		"composer":    composer.String,
		"label":       label.String,
		"copyright":   copyright.String,
		"format":      format.String,
	}
	return result, nil
}

func GetLocalLibraryPage(limit, offset int, searchQuery, sortMode string) (string, error) {
	db, err := GetMasterDB()
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
	db, err := GetMasterDB()
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

type LocalLibraryAlbumGroup struct {
	AlbumName     string `json:"album_name"`
	ArtistName    string `json:"artist_name"`
	CoverPath     string `json:"cover_path,omitempty"`
	TrackCount    int    `json:"track_count"`
	LatestScanned string `json:"latest_scanned"`
}

func GetLocalLibraryAlbumGroups(limit, offset int, searchQuery string) (string, error) {
	db, err := GetMasterDB()
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
		var coverPath sql.NullString
		var latestScanned sql.NullString
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
	db, err := GetMasterDB()
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

func DeleteLocalLibraryEntryByID(id string) error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	_, err = db.Exec("DELETE FROM files WHERE id = ? AND source = 'local_scan'", id)
	return err
}

func UpdateLocalLibraryAudioMetadata(entryJSON string) error {
	var entry map[string]interface{}
	if err := json.Unmarshal([]byte(entryJSON), &entry); err != nil {
		return err
	}

	id, ok := entry["id"].(string)
	if !ok || id == "" {
		return fmt.Errorf("missing id in entry")
	}

	db, err := GetMasterDB()
	if err != nil {
		return err
	}

	// Look up metadata_id from files table (id may be id or file_path)
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

func GetLocalLibraryEntryByID(id string) (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	rows, err := db.Query(`
		SELECT `+libraryColumns()+`
		FROM metadata m JOIN files f ON m.id = f.metadata_id
		WHERE m.id = ? AND f.source = 'local_scan'`, id)
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

func GetLocalLibraryEntryByIsrc(isrc string) (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	rows, err := db.Query(`
		SELECT `+libraryColumns()+`
		FROM metadata m JOIN files f ON m.id = f.metadata_id
		WHERE m.isrc = ? AND f.source = 'local_scan'`, isrc)
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

func FindLocalLibraryEntryByTrackAndArtist(track, artist string) (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	rows, err := db.Query(`
		SELECT `+libraryColumns()+`
		FROM metadata m JOIN files f ON m.id = f.metadata_id
		WHERE LOWER(m.track_name) = LOWER(?) AND LOWER(m.artist_name) = LOWER(?) AND f.source = 'local_scan'
		LIMIT 1`, track, artist)
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

func GetLocalLibraryCoverPaths() (string, error) {
	db, err := GetMasterDB()
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
	db, err := GetMasterDB()
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

func UpdateLocalLibraryFileModTimes(entriesJSON string) error {
	var entries map[string]int64
	if err := json.Unmarshal([]byte(entriesJSON), &entries); err != nil {
		return err
	}
	db, err := GetMasterDB()
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

func GetLocalLibraryArtistTracks(artist string) (string, error) {
	db, err := GetMasterDB()
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
	db, err := GetMasterDB()
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

// --- Collections ---

func UpsertCollection(itemJSON string) error {
	var item map[string]interface{}
	if err := json.Unmarshal([]byte(itemJSON), &item); err != nil {
		return err
	}
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	_, err = db.Exec(`
		INSERT INTO collections (id, name, type, cover_path, created_at, updated_at, custom_json, item_json)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(id) DO UPDATE SET
			name=excluded.name, type=excluded.type, cover_path=excluded.cover_path,
			created_at=excluded.created_at, updated_at=excluded.updated_at,
			custom_json=excluded.custom_json, item_json=excluded.item_json`,
		nvl(item["id"]), nvl(item["name"]), nvl(item["type"]), nvl(item["cover_path"]),
		nvl(item["created_at"]), nvl(item["updated_at"]), nvl(item["custom_json"]),
		nvl(item["item_json"]))
	return err
}

func DeleteCollection(id string) error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	_, err = db.Exec("DELETE FROM collections WHERE id = ?", id)
	return err
}

func AddToCollection(collectionID, itemID, addedAt, itemJSON string) error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	if addedAt == "" {
		addedAt = time.Now().UTC().Format(time.RFC3339)
	}
	_, err = db.Exec(`
		INSERT INTO collection_items (collection_id, item_id, item_json, added_at)
		VALUES (?, ?, ?, ?)
		ON CONFLICT(collection_id, item_id) DO UPDATE SET
			item_json=excluded.item_json, added_at=excluded.added_at`,
		collectionID, itemID, itemJSON, addedAt)
	return err
}

func RemoveFromCollection(collectionID, itemID string) error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	_, err = db.Exec("DELETE FROM collection_items WHERE collection_id = ? AND (metadata_id = ? OR item_id = ?)", collectionID, itemID, itemID)
	return err
}

func GetAllCollections() (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	rows, err := db.Query("SELECT * FROM collections ORDER BY updated_at DESC")
	if err != nil {
		return "", err
	}
	defer rows.Close()
	return rowsToJSON(rows), nil
}

func GetCollectionItems(collectionID string) (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	rows, err := db.Query("SELECT * FROM collection_items WHERE collection_id = ? ORDER BY position, added_at", collectionID)
	if err != nil {
		return "", err
	}
	defer rows.Close()
	return rowsToJSON(rows), nil
}

func GetAllCollectionItems() (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	rows, err := db.Query("SELECT * FROM collection_items ORDER BY position, added_at")
	if err != nil {
		return "", err
	}
	defer rows.Close()
	return rowsToJSON(rows), nil
}

func GetCollectionItemIDsByItemID(itemID string) (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	rows, err := db.Query("SELECT collection_id, item_id FROM collection_items WHERE item_id = ?", itemID)
	if err != nil {
		return "", err
	}
	defer rows.Close()
	return rowsToJSON(rows), nil
}

// --- Play History ---

func LogPlay(trackID, trackName, artistName, albumName, playedAt string, durationMs, percentage int) error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	if playedAt == "" {
		playedAt = time.Now().UTC().Format(time.RFC3339)
	}
	_, err = db.Exec(`
		INSERT INTO play_history (track_id, track_name, artist_name, album_name, played_at, duration_ms, percentage)
		VALUES (?, ?, ?, ?, ?, ?, ?)`,
		trackID, trackName, artistName, albumName, playedAt, durationMs, percentage)
	return err
}

func GetRecentPlays(limit int) (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	rows, err := db.Query("SELECT * FROM play_history ORDER BY played_at DESC LIMIT ?", limit)
	if err != nil {
		return "", err
	}
	defer rows.Close()
	return rowsToJSON(rows), nil
}

func ClearPlayHistory() error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	_, err = db.Exec("DELETE FROM play_history")
	return err
}

// --- Play Aggregates ---

func IncrementPlayCount(itemID, itemType string) error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	_, err = db.Exec(`
		INSERT INTO play_aggregates (item_id, type, play_count, last_played_at)
		VALUES (?, ?, 1, ?)
		ON CONFLICT(item_id) DO UPDATE SET
			play_count = play_count + 1,
			last_played_at = excluded.last_played_at`,
		itemID, itemType, time.Now().UTC().Format(time.RFC3339))
	return err
}

func GetPlayAggregates(itemType string) (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	var rows *sql.Rows
	if itemType != "" {
		rows, err = db.Query("SELECT * FROM play_aggregates WHERE type = ? ORDER BY play_count DESC", itemType)
	} else {
		rows, err = db.Query("SELECT * FROM play_aggregates ORDER BY play_count DESC")
	}
	if err != nil {
		return "", err
	}
	defer rows.Close()
	return rowsToJSON(rows), nil
}

// --- Stats (Total Stats, Top lists, Secrets) ---

func GetTotalStats() (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	var totalPlays, tracks, albums, artists int
	if err := db.QueryRow("SELECT COALESCE(SUM(play_count),0) FROM play_aggregates WHERE type = 'track'").Scan(&totalPlays); err != nil {
		GoLog("[DB] GetTotalStats totalPlays warning: %v", err)
	}
	if err := db.QueryRow("SELECT COUNT(*) FROM play_aggregates WHERE type = 'track'").Scan(&tracks); err != nil {
		GoLog("[DB] GetTotalStats tracks warning: %v", err)
	}
	if err := db.QueryRow("SELECT COUNT(*) FROM play_aggregates WHERE type = 'album'").Scan(&albums); err != nil {
		GoLog("[DB] GetTotalStats albums warning: %v", err)
	}
	if err := db.QueryRow("SELECT COUNT(*) FROM play_aggregates WHERE type = 'artist'").Scan(&artists); err != nil {
		GoLog("[DB] GetTotalStats artists warning: %v", err)
	}

	result := map[string]interface{}{
		"totalPlays":    totalPlays,
		"uniqueTracks":  tracks,
		"uniqueAlbums":  albums,
		"uniqueArtists": artists,
		"totalDays":     0,
	}
	out, err := json.Marshal(result)
	if err != nil {
		return "", err
	}
	return string(out), nil
}

func GetTopTracks(limit int) (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	rows, err := db.Query("SELECT * FROM play_aggregates WHERE type = 'track' ORDER BY play_count DESC LIMIT ?", limit)
	if err != nil {
		return "", err
	}
	defer rows.Close()
	return rowsToJSON(rows), nil
}

func GetTopAlbums(limit int) (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	rows, err := db.Query("SELECT * FROM play_aggregates WHERE type = 'album' ORDER BY play_count DESC LIMIT ?", limit)
	if err != nil {
		return "", err
	}
	defer rows.Close()
	return rowsToJSON(rows), nil
}

func GetTopArtists(limit int) (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	rows, err := db.Query("SELECT * FROM play_aggregates WHERE type = 'artist' ORDER BY play_count DESC LIMIT ?", limit)
	if err != nil {
		return "", err
	}
	defer rows.Close()
	return rowsToJSON(rows), nil
}

func GetSecretCounter(key string) (int, error) {
	db, err := GetMasterDB()
	if err != nil {
		return 0, err
	}
	var count int
	err = db.QueryRow("SELECT COALESCE(value,0) FROM secret_counters WHERE key = ?", key).Scan(&count)
	return count, err
}

func IncrementNightPlays() error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	_, err = db.Exec("INSERT INTO secret_counters (key, value) VALUES ('night_plays', 1) ON CONFLICT(key) DO UPDATE SET value = value + 1")
	return err
}

func UpdateAlbumStreak(streak int) error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	var current int
	db.QueryRow("SELECT COALESCE(value,0) FROM secret_counters WHERE key = 'max_album_streak'").Scan(&current)
	if streak > current {
		_, err = db.Exec("INSERT INTO secret_counters (key, value) VALUES ('max_album_streak', ?) ON CONFLICT(key) DO UPDATE SET value = ?", streak, streak)
	}
	return err
}

func IsSecretUnlocked(key string) (bool, error) {
	db, err := GetMasterDB()
	if err != nil {
		return false, err
	}
	var count int
	db.QueryRow("SELECT COUNT(*) FROM secret_unlocks WHERE key = ?", key).Scan(&count)
	return count > 0, nil
}

func UnlockSecret(key string) error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	_, err = db.Exec("INSERT OR IGNORE INTO secret_unlocks (key, unlocked_at) VALUES (?, ?)",
		key, time.Now().UTC().Format(time.RFC3339))
	return err
}

func GetUnlockedSecrets() (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	rows, err := db.Query("SELECT key FROM secret_unlocks")
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var keys []string
	for rows.Next() {
		var k string
		if err := rows.Scan(&k); err == nil {
			keys = append(keys, k)
		}
	}
	if keys == nil {
		keys = []string{}
	}
	out, _ := json.Marshal(keys)
	return string(out), nil
}

func ClearAllStats() error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	if _, err := db.Exec("DELETE FROM play_history"); err != nil {
		return fmt.Errorf("clear play_history: %w", err)
	}
	if _, err := db.Exec("DELETE FROM play_aggregates"); err != nil {
		return fmt.Errorf("clear play_aggregates: %w", err)
	}
	if _, err := db.Exec("DELETE FROM secret_counters"); err != nil {
		return fmt.Errorf("clear secret_counters: %w", err)
	}
	if _, err := db.Exec("DELETE FROM secret_unlocks"); err != nil {
		return fmt.Errorf("clear secret_unlocks: %w", err)
	}
	return nil
}

// --- Download Queue (Go-managed in master DB) ---

func SaveDownloadQueue(itemsJSON string) error {
	var items []map[string]interface{}
	if err := json.Unmarshal([]byte(itemsJSON), &items); err != nil {
		return err
	}
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if _, err := tx.Exec("DELETE FROM download_queue"); err != nil {
		return fmt.Errorf("clear download_queue: %w", err)
	}
	now := time.Now().UTC().Format(time.RFC3339)
	for _, item := range items {
		id, _ := item["id"].(string)
		trackJSON, _ := item["track_json"].(string)
		itemJSON, _ := item["item_json"].(string)
		status, _ := item["status"].(string)
		if status == "" {
			status = "pending"
		}
		progress := 0.0
		if p, ok := item["progress"].(float64); ok {
			progress = p
		}
		_, err = tx.Exec(`
			INSERT INTO download_queue (id, track_json, item_json, status, progress, created_at, updated_at, added_at)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
			id, trackJSON, itemJSON, status, progress, now, now, now)
		if err != nil {
			return err
		}
	}
	return tx.Commit()
}

func LoadDownloadQueue() (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	rows, err := db.Query("SELECT * FROM download_queue ORDER BY added_at ASC")
	if err != nil {
		return "", err
	}
	defer rows.Close()
	return rowsToJSON(rows), nil
}

func GetPendingDownloadQueueRows() (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	rows, err := db.Query("SELECT * FROM download_queue WHERE status = 'pending' ORDER BY added_at ASC")
	if err != nil {
		return "", err
	}
	defer rows.Close()
	return rowsToJSON(rows), nil
}

// GetPendingDownloadQueueRowsJSON is an alias for gomobile binding compatibility
func GetPendingDownloadQueueRowsJSON() (string, error) {
	return GetPendingDownloadQueueRows()
}

func ReplacePendingDownloadQueueRows(rowsJSON string) error {
	var rows []map[string]interface{}
	if err := json.Unmarshal([]byte(rowsJSON), &rows); err != nil {
		return err
	}
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	_, _ = tx.Exec("DELETE FROM download_queue WHERE status = 'pending'")
	now := time.Now().UTC().Format(time.RFC3339)
	for _, item := range rows {
		id, _ := item["id"].(string)
		trackJSON, _ := item["track_json"].(string)
		itemJSON, _ := item["item_json"].(string)
		_, err = tx.Exec(`
			INSERT INTO download_queue (id, track_json, item_json, status, progress, created_at, updated_at, added_at)
			VALUES (?, ?, ?, 'pending', 0, ?, ?, ?)`,
			id, trackJSON, itemJSON, now, now, now)
		if err != nil {
			return err
		}
	}
	return tx.Commit()
}

// --- Recent Access ---

func UpsertRecentAccessRow(key, itemJSON, accessedAt string) error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	if accessedAt == "" {
		accessedAt = time.Now().UTC().Format(time.RFC3339)
	}
	_, err = db.Exec(`
		INSERT INTO recent_access (id, item_json, type, accessed_at)
		VALUES (?, ?, 'recent', ?)
		ON CONFLICT(id) DO UPDATE SET item_json=excluded.item_json, accessed_at=excluded.accessed_at`,
		key, itemJSON, accessedAt)
	return err
}

func GetRecentAccessRows(limit int) (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	rows, err := db.Query("SELECT id AS key, item_json AS json, accessed_at FROM recent_access ORDER BY accessed_at DESC LIMIT ?", limit)
	if err != nil {
		return "", err
	}
	defer rows.Close()
	return rowsToJSON(rows), nil
}

func DeleteRecentAccessRow(key string) error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	_, err = db.Exec("DELETE FROM recent_access WHERE id = ?", key)
	return err
}

func ClearRecentAccessRows() error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	_, err = db.Exec("DELETE FROM recent_access")
	return err
}

// --- Hidden Download IDs ---

func GetHiddenRecentDownloadIds() (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	rows, err := db.Query("SELECT download_id FROM hidden_download_ids")
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err == nil {
			ids = append(ids, id)
		}
	}
	if ids == nil {
		ids = []string{}
	}
	out, _ := json.Marshal(ids)
	return string(out), nil
}

func AddHiddenRecentDownloadId(downloadID string) error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	_, err = db.Exec("INSERT OR IGNORE INTO hidden_download_ids (download_id) VALUES (?)", downloadID)
	return err
}

func ClearHiddenRecentDownloadIds() error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	_, err = db.Exec("DELETE FROM hidden_download_ids")
	return err
}

// --- App Settings ---
func SaveAppSettings(jsonStr string) error {
	// Validate JSON is not empty
	if strings.TrimSpace(jsonStr) == "" {
		return fmt.Errorf("empty JSON string")
	}
	// Validate it's valid JSON
	var js json.RawMessage
	if err := json.Unmarshal([]byte(jsonStr), &js); err != nil {
		return fmt.Errorf("invalid JSON: %w", err)
	}

	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	_, err = db.Exec(`INSERT INTO application_state (key, value, updated_at) VALUES ('app_settings', ?, datetime('now')) ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at`, jsonStr)
	return err
}
func LoadAppSettings() (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	var value string
	err = db.QueryRow("SELECT value FROM application_state WHERE key = 'app_settings'").Scan(&value)
	if err == sql.ErrNoRows {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	return value, nil
}

func SaveTranslationLanguage(language string) error {
	if strings.TrimSpace(language) == "" {
		return fmt.Errorf("empty language string")
	}
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	_, err = db.Exec(`INSERT INTO application_state (key, value, updated_at) VALUES ('translation_language', ?, datetime('now')) ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at`, language)
	return err
}

func LoadTranslationLanguage() (string, error) {
	db, err := GetMasterDB()
	if err != nil {
		return "", err
	}
	var value string
	err = db.QueryRow("SELECT value FROM application_state WHERE key = 'translation_language'").Scan(&value)
	if err == sql.ErrNoRows {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	return value, nil
}

// --- Helpers ---

func nvl(v interface{}) interface{} {
	if v == nil {
		return ""
	}
	switch val := v.(type) {
	case string:
		return val
	default:
		return v
	}
}

// --- Missing Go methods created to align with Flutter -> Go -> BSD flow ---

func GetLocalLibrarySingleTrackCount(searchQuery string) (int, error) {
	db, err := GetMasterDB()
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
	db, err := GetMasterDB()
	if err != nil {
		return 0, err
	}

	// Build placeholders
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

func UpsertDownloadEntryJSON(requestJSON string) error {
	var entry DownloadHistoryEntry
	if err := json.Unmarshal([]byte(requestJSON), &entry); err != nil {
		return fmt.Errorf("invalid download entry JSON: %w", err)
	}
	return UpsertDownloadEntry(entry)
}

func UpdateDownloadAudioMetadataJSON(requestJSON string) error {
	var entry DownloadHistoryEntry
	if err := json.Unmarshal([]byte(requestJSON), &entry); err != nil {
		return fmt.Errorf("invalid download entry JSON: %w", err)
	}
	return UpdateDownloadAudioMetadata(entry)
}

func DeleteDownloadEntriesByIDsJSON(requestJSON string) error {
	var ids []string
	if err := json.Unmarshal([]byte(requestJSON), &ids); err != nil {
		return fmt.Errorf("invalid ids JSON: %w", err)
	}
	return DeleteDownloadEntriesByIDs(ids)
}

func DeleteLocalLibraryEntriesByPathsJSON(requestJSON string) error {
	var paths []string
	if err := json.Unmarshal([]byte(requestJSON), &paths); err != nil {
		return fmt.Errorf("invalid paths JSON: %w", err)
	}
	return DeleteLocalLibraryEntriesByPaths(paths)
}

func UpsertLocalLibraryEntryJSON(requestJSON string) error {
	var entry DownloadHistoryEntry
	if err := json.Unmarshal([]byte(requestJSON), &entry); err != nil {
		return fmt.Errorf("invalid local library entry JSON: %w", err)
	}
	return UpsertLocalLibraryEntry(entry)
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

	db, err := GetMasterDB()
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

func ResetDatabase() error {
	db, err := GetMasterDB()
	if err != nil {
		return err
	}
	tables := []string{
		"metadata", "files", "favorites", "collections", "collection_items",
		"play_history", "play_aggregates", "secret_counters", "secret_unlocks",
		"download_queue", "recent_access", "hidden_download_ids", "application_state",
	}
	for _, table := range tables {
		_, _ = db.Exec("DELETE FROM " + table)
	}
	return nil
}

func rowsToJSON(rows *sql.Rows) string {
	cols, err := rows.Columns()
	if err != nil {
		GoLog("[DB] rowsToJSON Columns() error: %v", err)
		return "[]"
	}
	var results []map[string]interface{}
	for rows.Next() {
		vals := make([]interface{}, len(cols))
		valPtrs := make([]interface{}, len(cols))
		for i := range vals {
			valPtrs[i] = &vals[i]
		}
		if err := rows.Scan(valPtrs...); err != nil {
			GoLog("[DB] rowsToJSON Scan() error: %v", err)
			continue
		}
		row := make(map[string]interface{})
		for i, col := range cols {
			if vals[i] != nil {
				switch v := vals[i].(type) {
				case []byte:
					row[col] = string(v)
				default:
					row[col] = v
				}
			}
		}
		results = append(results, row)
	}
	if results == nil {
		results = []map[string]interface{}{}
	}
	out, err := json.Marshal(results)
	if err != nil {
		GoLog("[DB] rowsToJSON Marshal() error: %v", err)
		return "[]"
	}
	return string(out)
}
