package metadata

import (
	"fmt"

	flac "github.com/go-flac/go-flac/v2"
	flacvorbis "github.com/go-flac/flacvorbis/v2"
)

// ReadMetadata reads all Vorbis Comment tags from a FLAC file.
func ReadMetadata(filePath string) (*Metadata, error) {
	f, err := flac.ParseFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to parse FLAC file: %w", err)
	}

	meta := &Metadata{}
	for _, metaBlock := range f.Meta {
		if metaBlock.Type != flac.VorbisComment {
			continue
		}
		cmt, err := flacvorbis.ParseFromMetaDataBlock(*metaBlock)
		if err != nil {
			continue
		}

		meta.Title = getComment(cmt, "TITLE")
		meta.Artist = getJoinedComment(cmt, "ARTIST")
		meta.Album = getComment(cmt, "ALBUM")
		meta.AlbumArtist = getJoinedComment(cmt, "ALBUMARTIST")
		if meta.AlbumArtist == "" {
			meta.AlbumArtist = getJoinedComment(cmt, "ALBUM ARTIST")
		}
		if meta.AlbumArtist == "" {
			meta.AlbumArtist = getJoinedComment(cmt, "ALBUM_ARTIST")
		}
		meta.Date = getComment(cmt, "DATE")
		meta.ISRC = getComment(cmt, "ISRC")
		meta.Description = getComment(cmt, "DESCRIPTION")
		meta.Lyrics = getComment(cmt, "LYRICS")
		if meta.Lyrics == "" {
			meta.Lyrics = getComment(cmt, "UNSYNCEDLYRICS")
		}

		if v := getComment(cmt, "TRACKNUMBER"); v != "" {
			meta.TrackNumber, meta.TotalTracks = ParseIndexPair(v)
		}
		if meta.TrackNumber == 0 {
			if v := getComment(cmt, "TRACK"); v != "" {
				meta.TrackNumber, meta.TotalTracks = ParseIndexPair(v)
			}
		}
		if v := getComment(cmt, "DISCNUMBER"); v != "" {
			meta.DiscNumber, meta.TotalDiscs = ParseIndexPair(v)
		}
		if meta.DiscNumber == 0 {
			if v := getComment(cmt, "DISC"); v != "" {
				meta.DiscNumber, meta.TotalDiscs = ParseIndexPair(v)
			}
		}
		if meta.Date == "" {
			meta.Date = getComment(cmt, "YEAR")
		}
		meta.Genre = getComment(cmt, "GENRE")
		meta.Label = getComment(cmt, "ORGANIZATION")
		if meta.Label == "" {
			meta.Label = getComment(cmt, "LABEL")
		}
		if meta.Label == "" {
			meta.Label = getComment(cmt, "PUBLISHER")
		}
		meta.Copyright = getComment(cmt, "COPYRIGHT")
		meta.Composer = getComment(cmt, "COMPOSER")
		meta.Comment = getComment(cmt, "COMMENT")
		meta.ReplayGainTrackGain = getComment(cmt, "REPLAYGAIN_TRACK_GAIN")
		meta.ReplayGainTrackPeak = getComment(cmt, "REPLAYGAIN_TRACK_PEAK")
		meta.ReplayGainAlbumGain = getComment(cmt, "REPLAYGAIN_ALBUM_GAIN")
		meta.ReplayGainAlbumPeak = getComment(cmt, "REPLAYGAIN_ALBUM_PEAK")
		break
	}

	return meta, nil
}
