package handlers

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/audio/metadata"
)

func reEnrichFLAC(req reEnrichRequest, coverData []byte, shouldUpdate func(string) bool) interface{} {
	meta := metadata.Metadata{}
	if shouldUpdate("basic_tags") {
		meta.Title = req.TrackName
		meta.Artist = req.ArtistName
		meta.Album = req.AlbumName
		meta.AlbumArtist = req.AlbumArtist
	}
	if shouldUpdate("release_info") {
		meta.Date = req.Date
		meta.ISRC = req.ISRC
	}
	if shouldUpdate("extra") {
		meta.Genre = req.Genre
		meta.Label = req.Label
		meta.Copyright = req.Copyright
		meta.Composer = req.Composer
	}
	if shouldUpdate("track_info") {
		meta.TrackNumber = req.TrackNumber
		meta.TotalTracks = req.TotalTracks
		meta.DiscNumber = req.DiscNumber
		meta.TotalDiscs = req.TotalDiscs
	}

	var err error
	if len(coverData) > 0 {
		err = metadata.EmbedMetadataWithCoverData(req.FilePath, meta, coverData)
	} else {
		err = metadata.EmbedMetadata(req.FilePath, meta, "")
	}
	if err != nil {
		return map[string]interface{}{"success": false, "error": err.Error()}
	}

	return map[string]interface{}{
		"method":  "native",
		"success": true,
		"enriched_metadata": map[string]interface{}{
			"track_name":  req.TrackName,
			"artist_name": req.ArtistName,
			"album_name":  req.AlbumName,
			"isrc":        req.ISRC,
		},
	}
}
