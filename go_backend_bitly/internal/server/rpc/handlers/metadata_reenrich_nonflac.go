package handlers

import "fmt"

func reEnrichNonFLAC(req reEnrichRequest, coverTempPath string, shouldUpdate func(string) bool) interface{} {
	ffmpegMeta := map[string]string{}
	if shouldUpdate("basic_tags") {
		if req.TrackName != "" {
			ffmpegMeta["TITLE"] = req.TrackName
		}
		if req.ArtistName != "" {
			ffmpegMeta["ARTIST"] = req.ArtistName
		}
		if req.AlbumName != "" {
			ffmpegMeta["ALBUM"] = req.AlbumName
		}
		if req.AlbumArtist != "" {
			ffmpegMeta["ALBUMARTIST"] = req.AlbumArtist
		}
	}
	if shouldUpdate("release_info") {
		if req.Date != "" {
			ffmpegMeta["DATE"] = req.Date
		}
		if req.ISRC != "" {
			ffmpegMeta["ISRC"] = req.ISRC
		}
	}
	if shouldUpdate("extra") {
		if req.Genre != "" {
			ffmpegMeta["GENRE"] = req.Genre
		}
		if req.Label != "" {
			ffmpegMeta["ORGANIZATION"] = req.Label
		}
		if req.Copyright != "" {
			ffmpegMeta["COPYRIGHT"] = req.Copyright
		}
		if req.Composer != "" {
			ffmpegMeta["COMPOSER"] = req.Composer
		}
	}
	if shouldUpdate("track_info") {
		if req.TrackNumber > 0 {
			ffmpegMeta["TRACKNUMBER"] = fmt.Sprintf("%d/%d", req.TrackNumber, req.TotalTracks)
		}
		if req.DiscNumber > 0 {
			ffmpegMeta["DISCNUMBER"] = fmt.Sprintf("%d/%d", req.DiscNumber, req.TotalDiscs)
		}
	}

	return map[string]interface{}{
		"method":     "ffmpeg",
		"cover_path": coverTempPath,
		"lyrics":     "",
		"metadata":   ffmpegMeta,
		"enriched_metadata": map[string]interface{}{
			"track_name":  req.TrackName,
			"artist_name": req.ArtistName,
			"album_name":  req.AlbumName,
			"isrc":        req.ISRC,
		},
	}
}
