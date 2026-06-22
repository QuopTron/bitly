package database

import (
	"database/sql"
	"encoding/json"
)

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
