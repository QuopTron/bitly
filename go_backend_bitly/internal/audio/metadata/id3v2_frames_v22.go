package metadata

func parseID3v22Frames(data []byte, meta *AudioMetadata, tagUnsync bool) {
	pos := 0
	for pos+6 < len(data) {
		frameID := string(data[pos : pos+3])
		if frameID[0] == 0 {
			break
		}
		frameSize := int(data[pos+3])<<16 | int(data[pos+4])<<8 | int(data[pos+5])
		if frameSize <= 0 || pos+6+frameSize > len(data) {
			break
		}
		frameData := data[pos+6 : pos+6+frameSize]
		if tagUnsync {
			frameData = removeUnsync(frameData)
		}
		value := FirstTextValue(extractTextFrame(frameData))

		switch frameID {
		case "TT2":
			meta.Title = value
		case "TP1":
			meta.Artist = value
		case "TP2":
			meta.AlbumArtist = value
		case "TAL":
			meta.Album = value
		case "TYE":
			meta.Year = value
		case "TCO":
			meta.Genre = CleanGenre(value)
		case "TRK":
			meta.TrackNumber, meta.TotalTracks = ParseIndexPair(value)
		case "TPA":
			meta.DiscNumber, meta.TotalDiscs = ParseIndexPair(value)
		case "TCM":
			meta.Composer = value
		case "TPB":
			meta.Label = value
		case "TCR":
			meta.Copyright = value
		case "ULT":
			if v := extractLyricsFrame(frameData); v != "" && meta.Lyrics == "" {
				meta.Lyrics = v
			}
		case "TXX":
			desc, uv := extractUserTextFrame(frameData)
			if isLyricsDescription(desc) && uv != "" && meta.Lyrics == "" {
				meta.Lyrics = uv
			}
		}
		pos += 6 + frameSize
	}
}
