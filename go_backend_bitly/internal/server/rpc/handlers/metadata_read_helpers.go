package handlers

import (
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/audio/metadata"
)

func readMetadataAPE(filePath string) map[string]interface{} {
	apeTag, apeErr := metadata.ReadAPETags(filePath)
	if apeErr == nil && apeTag != nil {
		meta := metadata.APETagToAudioMetadata(apeTag)
		if meta != nil {
			return audioMetadataToResult(meta)
		}
	}
	return nil
}

func readMetadataGeneric(filePath string) map[string]interface{} {
	meta, err := metadata.ReadAudioMetadataFromFile(filePath)
	if err == nil && meta != nil {
		return audioMetadataToResult(meta)
	}
	return nil
}

func readMetadataFLACFallback(filePath string, result map[string]interface{}) {
	lower := strings.ToLower(filePath)
	if !strings.HasSuffix(lower, ".flac") {
		return
	}
	oggMeta, oggErr := metadata.ReadOggVorbisComments(filePath)
	if oggErr == nil && oggMeta != nil {
		result["title"] = oggMeta.Title
		result["artist"] = oggMeta.Artist
		result["album"] = oggMeta.Album
		result["album_artist"] = oggMeta.AlbumArtist
		result["date"] = oggMeta.Date
		if oggMeta.Date == "" {
			result["date"] = oggMeta.Year
		}
		result["track_number"] = oggMeta.TrackNumber
		result["total_tracks"] = oggMeta.TotalTracks
		result["disc_number"] = oggMeta.DiscNumber
		result["total_discs"] = oggMeta.TotalDiscs
		result["isrc"] = oggMeta.ISRC
		result["lyrics"] = oggMeta.Lyrics
		result["genre"] = oggMeta.Genre
		result["composer"] = oggMeta.Composer
		result["comment"] = oggMeta.Comment
		if quality, qErr := metadata.GetOggQuality(filePath); qErr == nil {
			result["sample_rate"] = quality.SampleRate
			result["duration"] = quality.Duration
			if quality.Bitrate > 0 {
				result["bitrate"] = quality.Bitrate / 1000
			}
		}
	}
}

func audioMetadataToResult(meta *metadata.AudioMetadata) map[string]interface{} {
	result := map[string]interface{}{
		"title":                   meta.Title,
		"artist":                  meta.Artist,
		"album":                   meta.Album,
		"album_artist":            meta.AlbumArtist,
		"date":                    meta.Date,
		"track_number":            meta.TrackNumber,
		"total_tracks":            meta.TotalTracks,
		"disc_number":             meta.DiscNumber,
		"total_discs":             meta.TotalDiscs,
		"isrc":                    meta.ISRC,
		"lyrics":                  meta.Lyrics,
		"genre":                   meta.Genre,
		"label":                   meta.Label,
		"copyright":               meta.Copyright,
		"composer":                meta.Composer,
		"comment":                 meta.Comment,
		"duration":                0,
		"replaygain_track_gain":   meta.ReplayGainTrackGain,
		"replaygain_track_peak":   meta.ReplayGainTrackPeak,
		"replaygain_album_gain":   meta.ReplayGainAlbumGain,
		"replaygain_album_peak":   meta.ReplayGainAlbumPeak,
	}
	if meta.Date == "" {
		result["date"] = meta.Year
	}
	return result
}
