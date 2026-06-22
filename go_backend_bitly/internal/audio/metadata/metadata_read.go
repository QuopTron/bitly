package metadata

import (
	"fmt"
	"strings"
)

// ReadAudioMetadataFromFile reads metadata from any supported audio format.
func ReadAudioMetadataFromFile(filePath string) (*AudioMetadata, error) {
	lower := strings.ToLower(filePath)
	switch {
	case strings.HasSuffix(lower, ".flac"):
		md, err := ReadMetadata(filePath)
		if err != nil {
			return nil, err
		}
		am := &AudioMetadata{
			Title:       md.Title,
			Artist:      md.Artist,
			Album:       md.Album,
			AlbumArtist: md.AlbumArtist,
			Genre:       md.Genre,
			Date:        md.Date,
			TrackNumber: md.TrackNumber,
			TotalTracks: md.TotalTracks,
			DiscNumber:  md.DiscNumber,
			TotalDiscs:  md.TotalDiscs,
			ISRC:        md.ISRC,
			Lyrics:      md.Lyrics,
			Label:       md.Label,
			Copyright:   md.Copyright,
			Composer:    md.Composer,
			Comment:     md.Comment,
		}
		if len(md.Date) >= 4 {
			am.Year = md.Date[:4]
		}
		return am, nil

	case strings.HasSuffix(lower, ".mp3"):
		return ReadID3Tags(filePath)

	case strings.HasSuffix(lower, ".m4a"), strings.HasSuffix(lower, ".aac"):
		return ReadM4ATags(filePath)

	case strings.HasSuffix(lower, ".opus"), strings.HasSuffix(lower, ".ogg"):
		return ReadOggVorbisComments(filePath)

	default:
		return nil, fmt.Errorf("unsupported format: %s", filePath)
	}
}
