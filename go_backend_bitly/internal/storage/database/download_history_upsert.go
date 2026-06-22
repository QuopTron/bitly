package database

import (
	"database/sql"
	"encoding/json"
	"fmt"
)

func UpsertDownloadEntry(entry DownloadHistoryEntry) error {
	return WithTx(func(tx *sql.Tx) error {
		_, err := tx.Exec(`
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
		return err
	})
}

func UpsertDownloadEntryJSON(requestJSON string) error {
	var entry DownloadHistoryEntry
	if err := json.Unmarshal([]byte(requestJSON), &entry); err != nil {
		return fmt.Errorf("invalid download entry JSON: %w", err)
	}
	return UpsertDownloadEntry(entry)
}

func UpdateDownloadAudioMetadata(entry DownloadHistoryEntry) error {
	db, err := Get()
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

func UpsertDownloadEntriesBatch(requestJSON string) error {
	var items []DownloadHistoryEntry
	if err := json.Unmarshal([]byte(requestJSON), &items); err != nil {
		return fmt.Errorf("UpsertDownloadEntriesBatch: %w", err)
	}
	for _, item := range items {
		if err := UpsertDownloadEntry(item); err != nil {
			return fmt.Errorf("UpsertDownloadEntriesBatch: %w", err)
		}
	}
	return nil
}

func UpdateDownloadAudioMetadataJSON(requestJSON string) error {
	var entry DownloadHistoryEntry
	if err := json.Unmarshal([]byte(requestJSON), &entry); err != nil {
		return fmt.Errorf("invalid download entry JSON: %w", err)
	}
	return UpdateDownloadAudioMetadata(entry)
}

func UpdateDownloadFilePath(id, filePath string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	_, err = db.Exec("UPDATE files SET file_path = ? WHERE id = ? AND source = 'download'", filePath, id)
	return err
}
