package metadata

import "strings"

func parseID3v23Frames(data []byte, meta *AudioMetadata, version byte, tagUnsync bool) {
	pos := 0
	for pos+10 < len(data) {
		frameID := string(data[pos : pos+4])
		if frameID[0] == 0 {
			break
		}
		var frameSize int
		if version == 4 {
			frameSize = int(data[pos+4])<<21 | int(data[pos+5])<<14 | int(data[pos+6])<<7 | int(data[pos+7])
		} else {
			frameSize = int(data[pos+4])<<24 | int(data[pos+5])<<16 | int(data[pos+6])<<8 | int(data[pos+7])
		}
		if frameSize <= 0 || pos+10+frameSize > len(data) {
			break
		}
		frameData := data[pos+10 : pos+10+frameSize]
		formatFlags := data[pos+9]

		if version == 3 {
			if formatFlags&0xC0 != 0 {
				pos += 10 + frameSize
				continue
			}
			if formatFlags&0x20 != 0 && len(frameData) > 0 {
				frameData = frameData[1:]
			}
			if tagUnsync {
				frameData = removeUnsync(frameData)
			}
		} else if version == 4 {
			if formatFlags&0x40 != 0 && len(frameData) > 0 {
				frameData = frameData[1:]
			}
			if formatFlags&0x01 != 0 && len(frameData) >= 4 {
				frameData = frameData[4:]
			}
			if formatFlags&0x02 != 0 || tagUnsync {
				frameData = removeUnsync(frameData)
			}
			if formatFlags&0x0C != 0 {
				pos += 10 + frameSize
				continue
			}
		}

		value := FirstTextValue(extractTextFrame(frameData))
		switch frameID {
		case "TIT2":
			meta.Title = value
		case "TPE1":
			meta.Artist = value
		case "TPE2":
			meta.AlbumArtist = value
		case "TALB":
			meta.Album = value
		case "TYER", "TDRC":
			meta.Year = value
			if len(value) >= 4 {
				meta.Date = value
			}
		case "TCON":
			meta.Genre = CleanGenre(value)
		case "TRCK":
			meta.TrackNumber, meta.TotalTracks = ParseIndexPair(value)
		case "TPOS":
			meta.DiscNumber, meta.TotalDiscs = ParseIndexPair(value)
		case "TSRC":
			meta.ISRC = value
		case "TCOM":
			meta.Composer = value
		case "TPUB":
			meta.Label = value
		case "TCOP":
			meta.Copyright = value
		case "COMM":
			if v := extractCommentFrame(frameData); v != "" {
				meta.Comment = v
			}
		case "USLT":
			if v := extractLyricsFrame(frameData); v != "" && meta.Lyrics == "" {
				meta.Lyrics = v
			}
		case "TXXX":
			desc, uv := extractUserTextFrame(frameData)
			if isLyricsDescription(desc) && uv != "" && meta.Lyrics == "" {
				meta.Lyrics = uv
			}
			switch strings.ToUpper(desc) {
			case "REPLAYGAIN_TRACK_GAIN":
				meta.ReplayGainTrackGain = uv
			case "REPLAYGAIN_TRACK_PEAK":
				meta.ReplayGainTrackPeak = uv
			case "REPLAYGAIN_ALBUM_GAIN":
				meta.ReplayGainAlbumGain = uv
			case "REPLAYGAIN_ALBUM_PEAK":
				meta.ReplayGainAlbumPeak = uv
			}
		}
		pos += 10 + frameSize
	}
}
