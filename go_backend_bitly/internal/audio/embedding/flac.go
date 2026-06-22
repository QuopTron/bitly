package embedding

import (
	"os"

	"github.com/zarz/bitly/go_backend_bitly/internal/audio/metadata"
)

func (e *Embedder) embedIntoFlac(req EmbedRequest) error {
	meta := metadata.Metadata{
		Title:         req.Title,
		Artist:        req.Artist,
		Album:         req.Album,
		AlbumArtist:   req.AlbumArtist,
		Date:          req.Date,
		TrackNumber:   req.TrackNum,
		TotalTracks:   req.TotalTracks,
		DiscNumber:    req.DiscNum,
		TotalDiscs:    req.TotalDiscs,
		ISRC:          req.ISRC,
		Genre:         req.Genre,
		Label:         req.Label,
		Copyright:     req.Copyright,
		Composer:      req.Composer,
		Lyrics:        req.Lyrics,
	}

	coverPath := req.CoverPath
	if coverPath == "" && e.coverDir != "" {
		coverPath = e.resolveCoverPath(req.AudioPath)
	}

	if coverPath != "" {
		coverData, err := os.ReadFile(coverPath)
		if err == nil && len(coverData) > 0 {
			return metadata.EmbedMetadataWithCoverData(req.AudioPath, meta, coverData)
		}
		return metadata.EmbedMetadata(req.AudioPath, meta, "")
	}
	return metadata.EmbedMetadata(req.AudioPath, meta, "")
}
