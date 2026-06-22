package library

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/audio/metadata"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

func scanAPEFile(filePath string, result *database.LibraryScanResult, displayNameHint string) (*database.LibraryScanResult, error) {
	tag, err := metadata.ReadAPETags(filePath)
	if err != nil {
		return scanFromFilename(filePath, displayNameHint, result)
	}

	am := metadata.APETagToAudioMetadata(tag)
	if am == nil {
		return scanFromFilename(filePath, displayNameHint, result)
	}

	result.TrackName = am.Title
	result.ArtistName = am.Artist
	result.AlbumName = am.Album
	result.AlbumArtist = am.AlbumArtist
	result.ISRC = am.ISRC
	result.TrackNumber = am.TrackNumber
	result.TotalTracks = am.TotalTracks
	result.DiscNumber = am.DiscNumber
	result.TotalDiscs = am.TotalDiscs
	result.Genre = am.Genre
	result.Composer = am.Composer
	result.Label = am.Label
	result.Copyright = am.Copyright

	if am.Date != "" {
		result.ReleaseDate = am.Date
	} else {
		result.ReleaseDate = am.Year
	}

	applyDefaultLibraryMetadata(filePath, displayNameHint, result)
	return result, nil
}
