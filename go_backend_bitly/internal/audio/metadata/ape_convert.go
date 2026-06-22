package metadata

import (
	"strings"
)

// APETagToAudioMetadata converts an APETag to our unified AudioMetadata struct.
func APETagToAudioMetadata(tag *APETag) *AudioMetadata {
	if tag == nil {
		return nil
	}
	meta := &AudioMetadata{}
	for _, item := range tag.Items {
		key := strings.ToUpper(strings.TrimSpace(item.Key))
		value := strings.TrimSpace(item.Value)
		if value == "" {
			continue
		}
		switch key {
		case "TITLE":
			meta.Title = value
		case "ARTIST":
			meta.Artist = value
		case "ALBUM":
			meta.Album = value
		case "ALBUMARTIST", "ALBUM ARTIST":
			meta.AlbumArtist = value
		case "GENRE":
			meta.Genre = value
		case "YEAR":
			meta.Year = value
		case "DATE":
			meta.Date = value
		case "TRACK", "TRACKNUMBER":
			meta.TrackNumber, meta.TotalTracks = ParseIndexPair(value)
		case "DISC", "DISCNUMBER":
			meta.DiscNumber, meta.TotalDiscs = ParseIndexPair(value)
		case "ISRC":
			meta.ISRC = value
		case "LYRICS", "UNSYNCEDLYRICS":
			if meta.Lyrics == "" {
				meta.Lyrics = value
			}
		case "LABEL", "PUBLISHER":
			meta.Label = value
		case "COPYRIGHT":
			meta.Copyright = value
		case "COMPOSER":
			meta.Composer = value
		case "COMMENT":
			meta.Comment = value
		case "REPLAYGAIN_TRACK_GAIN":
			meta.ReplayGainTrackGain = value
		case "REPLAYGAIN_TRACK_PEAK":
			meta.ReplayGainTrackPeak = value
		case "REPLAYGAIN_ALBUM_GAIN":
			meta.ReplayGainAlbumGain = value
		case "REPLAYGAIN_ALBUM_PEAK":
			meta.ReplayGainAlbumPeak = value
		}
	}
	return meta
}

// AudioMetadataToAPEItems converts metadata fields to APE tag items.
func AudioMetadataToAPEItems(meta *AudioMetadata) []APETagItem {
	if meta == nil {
		return nil
	}
	var items []APETagItem
	addItem := func(key, value string) {
		if value != "" {
			items = append(items, APETagItem{Key: key, Value: value})
		}
	}
	addItem("Title", meta.Title)
	addItem("Artist", meta.Artist)
	addItem("Album", meta.Album)
	addItem("Album Artist", meta.AlbumArtist)
	addItem("Genre", meta.Genre)
	if meta.Date != "" {
		addItem("Date", meta.Date)
	} else if meta.Year != "" {
		addItem("Year", meta.Year)
	}
	if meta.TrackNumber > 0 {
		addItem("Track", FormatIndexValue(meta.TrackNumber, meta.TotalTracks))
	}
	if meta.DiscNumber > 0 {
		addItem("Disc", FormatIndexValue(meta.DiscNumber, meta.TotalDiscs))
	}
	addItem("ISRC", meta.ISRC)
	addItem("Lyrics", meta.Lyrics)
	addItem("Label", meta.Label)
	addItem("Copyright", meta.Copyright)
	addItem("Composer", meta.Composer)
	addItem("Comment", meta.Comment)
	addItem("REPLAYGAIN_TRACK_GAIN", meta.ReplayGainTrackGain)
	addItem("REPLAYGAIN_TRACK_PEAK", meta.ReplayGainTrackPeak)
	addItem("REPLAYGAIN_ALBUM_GAIN", meta.ReplayGainAlbumGain)
	addItem("REPLAYGAIN_ALBUM_PEAK", meta.ReplayGainAlbumPeak)
	return items
}
