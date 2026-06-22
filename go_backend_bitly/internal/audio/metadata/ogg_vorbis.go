package metadata

import (
	"bytes"
	"encoding/binary"
	"io"
	"strings"
)

type oggStreamType int

const (
	oggStreamUnknown oggStreamType = iota
	oggStreamOpus
	oggStreamVorbis
)

func detectOggStreamType(packets [][]byte) oggStreamType {
	for _, p := range packets {
		if len(p) >= 8 && string(p[0:8]) == "OpusHead" {
			return oggStreamOpus
		}
		if len(p) > 7 && p[0] == 0x01 && string(p[1:7]) == "vorbis" {
			return oggStreamVorbis
		}
	}
	return oggStreamUnknown
}

func parseVorbisComments(data []byte, meta *AudioMetadata) {
	if len(data) < 4 {
		return
	}
	reader := bytes.NewReader(data)
	artistValues := make([]string, 0, 1)
	albumArtistValues := make([]string, 0, 1)

	var vendorLen uint32
	if err := binary.Read(reader, binary.LittleEndian, &vendorLen); err != nil {
		return
	}
	if vendorLen > uint32(len(data)-4) {
		return
	}
	reader.Seek(int64(vendorLen), io.SeekCurrent)

	var commentCount uint32
	if err := binary.Read(reader, binary.LittleEndian, &commentCount); err != nil {
		return
	}
	for i := uint32(0); i < commentCount && i < 100; i++ {
		var commentLen uint32
		if err := binary.Read(reader, binary.LittleEndian, &commentLen); err != nil {
			break
		}
		remaining := uint32(reader.Len())
		if commentLen > remaining {
			break
		}
		if commentLen > 512*1024 {
			reader.Seek(int64(commentLen), io.SeekCurrent)
			continue
		}
		comment := make([]byte, commentLen)
		if _, err := reader.Read(comment); err != nil {
			break
		}
		parts := strings.SplitN(string(comment), "=", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.ToUpper(parts[0])
		value := parts[1]

		switch key {
		case "TITLE":
			meta.Title = value
		case "ARTIST":
			artistValues = append(artistValues, value)
		case "ALBUMARTIST", "ALBUM_ARTIST", "ALBUM ARTIST":
			albumArtistValues = append(albumArtistValues, value)
		case "ALBUM":
			meta.Album = value
		case "DATE", "YEAR":
			meta.Date = value
			if len(value) >= 4 {
				meta.Year = value[:4]
			}
		case "GENRE":
			meta.Genre = value
		case "TRACKNUMBER", "TRACK":
			meta.TrackNumber, meta.TotalTracks = ParseIndexPair(value)
		case "DISCNUMBER", "DISC":
			meta.DiscNumber, meta.TotalDiscs = ParseIndexPair(value)
		case "ISRC":
			meta.ISRC = value
		case "COMPOSER":
			meta.Composer = value
		case "COMMENT", "DESCRIPTION":
			meta.Comment = value
		case "LYRICS", "UNSYNCEDLYRICS":
			if meta.Lyrics == "" {
				meta.Lyrics = value
			}
		case "ORGANIZATION", "LABEL", "PUBLISHER":
			meta.Label = value
		case "COPYRIGHT":
			meta.Copyright = value
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
	if len(artistValues) > 0 {
		meta.Artist = joinVorbisCommentValues(artistValues)
	}
	if len(albumArtistValues) > 0 {
		meta.AlbumArtist = joinVorbisCommentValues(albumArtistValues)
	}
}
