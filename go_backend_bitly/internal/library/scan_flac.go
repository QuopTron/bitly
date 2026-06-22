package library

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/audio/metadata"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

func scanFLACFile(filePath string, result *database.LibraryScanResult, displayNameHint string) (*database.LibraryScanResult, error) {
	md, err := metadata.ReadMetadata(filePath)
	if err != nil {
		return scanFromFilename(filePath, displayNameHint, result)
	}

	result.TrackName = md.Title
	result.ArtistName = md.Artist
	result.AlbumName = md.Album
	result.AlbumArtist = md.AlbumArtist
	result.ISRC = md.ISRC
	result.TrackNumber = md.TrackNumber
	result.TotalTracks = md.TotalTracks
	result.DiscNumber = md.DiscNumber
	result.TotalDiscs = md.TotalDiscs
	result.ReleaseDate = md.Date
	result.Genre = md.Genre
	result.Composer = md.Composer
	result.Label = md.Label
	result.Copyright = md.Copyright

	quality, err := metadata.GetFlacQuality(filePath)
	if err == nil {
		duration := 0
		if quality.SampleRate > 0 && quality.TotalSamples > 0 {
			duration = int(quality.TotalSamples / int64(quality.SampleRate))
		}
		applyQualityFields(result, quality.BitDepth, quality.SampleRate, duration, 0)
	}

	applyDefaultLibraryMetadata(filePath, displayNameHint, result)
	return result, nil
}
