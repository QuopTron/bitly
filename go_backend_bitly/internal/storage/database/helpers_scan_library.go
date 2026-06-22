package database

import "database/sql"

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
