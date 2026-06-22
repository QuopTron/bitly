package library

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/audio/metadata"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

func scanM4AFile(filePath string, result *database.LibraryScanResult, displayNameHint string) (*database.LibraryScanResult, error) {
	am, err := metadata.ReadM4ATags(filePath)
	if err != nil {
		return scanFromFilename(filePath, displayNameHint, result)
	}

	if am != nil {
		result.TrackName = am.Title
		result.ArtistName = am.Artist
		result.AlbumName = am.Album
		result.AlbumArtist = am.AlbumArtist
		result.ISRC = am.ISRC
		result.TrackNumber = am.TrackNumber
		result.TotalTracks = am.TotalTracks
		result.DiscNumber = am.DiscNumber
		result.TotalDiscs = am.TotalDiscs
		result.ReleaseDate = am.Date
		result.Genre = am.Genre
		result.Composer = am.Composer
		result.Label = am.Label
		result.Copyright = am.Copyright
		if result.ReleaseDate == "" && am.Year != "" {
			result.ReleaseDate = am.Year
		}
	}

	quality, err := metadata.GetM4AQuality(filePath)
	if err == nil {
		applyQualityFields(result, quality.BitDepth, quality.SampleRate, quality.Duration, 0)
	}

	applyDefaultLibraryMetadata(filePath, displayNameHint, result)
	return result, nil
}
