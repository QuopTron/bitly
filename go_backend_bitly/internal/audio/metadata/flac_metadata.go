package metadata

import "github.com/go-flac/flacvorbis/v2"

// Metadata holds tag values for embedding into FLAC files.
type Metadata struct {
	Title              string
	Artist             string
	Album              string
	AlbumArtist        string
	ArtistTagMode      string
	Date               string
	TrackNumber        int
	TotalTracks        int
	DiscNumber         int
	TotalDiscs         int
	ISRC               string
	Description        string
	Lyrics             string
	Genre              string
	Label              string
	Copyright          string
	Composer           string
	Comment            string
	ReplayGainTrackGain string
	ReplayGainTrackPeak string
	ReplayGainAlbumGain string
	ReplayGainAlbumPeak string
}

func writeVorbisMeta(cmt *flacvorbis.MetaDataBlockVorbisComment, meta Metadata) {
	setComment(cmt, "TITLE", meta.Title)
	setArtistComments(cmt, "ARTIST", meta.Artist, meta.ArtistTagMode)
	setComment(cmt, "ALBUM", meta.Album)
	setArtistComments(cmt, "ALBUMARTIST", meta.AlbumArtist, meta.ArtistTagMode)
	setComment(cmt, "DATE", meta.Date)
	if meta.TrackNumber > 0 {
		setComment(cmt, "TRACKNUMBER", FormatIndexValue(meta.TrackNumber, meta.TotalTracks))
	}
	if meta.DiscNumber > 0 {
		setComment(cmt, "DISCNUMBER", FormatIndexValue(meta.DiscNumber, meta.TotalDiscs))
	}
	if meta.ISRC != "" {
		setComment(cmt, "ISRC", meta.ISRC)
	}
	if meta.Description != "" {
		setComment(cmt, "DESCRIPTION", meta.Description)
	}
	if meta.Lyrics != "" {
		setComment(cmt, "LYRICS", meta.Lyrics)
		setComment(cmt, "UNSYNCEDLYRICS", meta.Lyrics)
	}
	if meta.Genre != "" {
		setComment(cmt, "GENRE", meta.Genre)
	}
	if meta.Label != "" {
		setComment(cmt, "ORGANIZATION", meta.Label)
	}
	if meta.Copyright != "" {
		setComment(cmt, "COPYRIGHT", meta.Copyright)
	}
	if meta.Composer != "" {
		setComment(cmt, "COMPOSER", meta.Composer)
	}
	if meta.Comment != "" {
		setComment(cmt, "COMMENT", meta.Comment)
	}
	setComment(cmt, "REPLAYGAIN_TRACK_GAIN", meta.ReplayGainTrackGain)
	setComment(cmt, "REPLAYGAIN_TRACK_PEAK", meta.ReplayGainTrackPeak)
	setComment(cmt, "REPLAYGAIN_ALBUM_GAIN", meta.ReplayGainAlbumGain)
	setComment(cmt, "REPLAYGAIN_ALBUM_PEAK", meta.ReplayGainAlbumPeak)
}
