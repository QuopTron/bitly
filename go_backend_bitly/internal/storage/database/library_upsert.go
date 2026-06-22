package database

import (
	"database/sql"
	"fmt"
)

func UpsertLibraryTrack(item LibraryScanResult) error {
	return WithTx(func(tx *sql.Tx) error {
		_, err := tx.Exec(`
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
				cover_path=COALESCE(excluded.cover_path, metadata.cover_path)`,
			item.ID, item.TrackName, item.ArtistName, item.AlbumName, item.AlbumArtist,
			item.ISRC, item.TrackNumber, item.TotalTracks, item.DiscNumber, item.TotalDiscs,
			item.Duration, item.ReleaseDate, item.Genre, item.Composer, item.Label, item.Copyright, item.CoverPath)
		if err != nil {
			return err
		}
		_, err = tx.Exec(`
			INSERT INTO files (
				id, metadata_id, file_path, source, format, bitrate, bit_depth, sample_rate, file_mod_time, scanned_at
			) VALUES (?, ?, ?, 'local_scan', ?, ?, ?, ?, ?, ?)
			ON CONFLICT(file_path) DO UPDATE SET
				metadata_id=excluded.metadata_id,
				format=excluded.format,
				bitrate=excluded.bitrate,
				bit_depth=excluded.bit_depth,
				sample_rate=excluded.sample_rate,
				file_mod_time=excluded.file_mod_time,
				scanned_at=excluded.scanned_at`,
			item.ID, item.ID, item.FilePath, item.Format, item.Bitrate, item.BitDepth, item.SampleRate, item.FileModTime, item.ScannedAt)
		return err
	})
}

func UpsertLibraryBatch(items []LibraryScanResult) error {
	return WithTx(func(tx *sql.Tx) error {
		stmtMeta, err := tx.Prepare(`
			INSERT INTO metadata (id, track_name, artist_name, album_name, album_artist, isrc, track_number, total_tracks, disc_number, total_discs, duration_ms, release_date, genre, composer, label, copyright, cover_path)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
			ON CONFLICT(id) DO UPDATE SET track_name=excluded.track_name, artist_name=excluded.artist_name, album_name=excluded.album_name, album_artist=excluded.album_artist, isrc=excluded.isrc, track_number=excluded.track_number, total_tracks=excluded.total_tracks, disc_number=excluded.disc_number, total_discs=excluded.total_discs, duration_ms=excluded.duration_ms, release_date=excluded.release_date, genre=excluded.genre, composer=excluded.composer, label=excluded.label, copyright=excluded.copyright, cover_path=COALESCE(excluded.cover_path, metadata.cover_path)`)
		if err != nil {
			return err
		}
		defer stmtMeta.Close()

		stmtFile, err := tx.Prepare(`
			INSERT INTO files (id, metadata_id, file_path, source, format, bitrate, bit_depth, sample_rate, file_mod_time, scanned_at)
			VALUES (?, ?, ?, 'local_scan', ?, ?, ?, ?, ?, ?)
			ON CONFLICT(file_path) DO UPDATE SET metadata_id=excluded.metadata_id, format=excluded.format, bitrate=excluded.bitrate, bit_depth=excluded.bit_depth, sample_rate=excluded.sample_rate, file_mod_time=excluded.file_mod_time, scanned_at=excluded.scanned_at`)
		if err != nil {
			return err
		}
		defer stmtFile.Close()

		for _, item := range items {
			if _, err := stmtMeta.Exec(item.ID, item.TrackName, item.ArtistName, item.AlbumName, item.AlbumArtist, item.ISRC, item.TrackNumber, item.TotalTracks, item.DiscNumber, item.TotalDiscs, item.Duration, item.ReleaseDate, item.Genre, item.Composer, item.Label, item.Copyright, item.CoverPath); err != nil {
				return fmt.Errorf("batch meta insert failed: %w", err)
			}
			if _, err := stmtFile.Exec(item.ID, item.ID, item.FilePath, item.Format, item.Bitrate, item.BitDepth, item.SampleRate, item.FileModTime, item.ScannedAt); err != nil {
				return fmt.Errorf("batch file insert failed: %w", err)
			}
		}
		return nil
	})
}


