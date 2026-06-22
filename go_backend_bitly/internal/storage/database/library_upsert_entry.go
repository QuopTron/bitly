package database

import (
	"database/sql"
	"encoding/json"
	"fmt"
)

func UpsertLocalLibraryEntry(entry DownloadHistoryEntry) error {
	return WithTx(func(tx *sql.Tx) error {
		_, err := tx.Exec(`
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
		return err
	})
}

func UpsertLocalLibraryEntriesBatch(requestJSON string) error {
	var items []DownloadHistoryEntry
	if err := json.Unmarshal([]byte(requestJSON), &items); err != nil {
		return fmt.Errorf("UpsertLocalLibraryEntriesBatch: %w", err)
	}
	for _, item := range items {
		if err := UpsertLocalLibraryEntry(item); err != nil {
			return fmt.Errorf("UpsertLocalLibraryEntriesBatch: %w", err)
		}
	}
	return nil
}

func UpsertLocalLibraryEntryJSON(requestJSON string) error {
	var entry DownloadHistoryEntry
	if err := json.Unmarshal([]byte(requestJSON), &entry); err != nil {
		return fmt.Errorf("invalid local library entry JSON: %w", err)
	}
	return UpsertLocalLibraryEntry(entry)
}
