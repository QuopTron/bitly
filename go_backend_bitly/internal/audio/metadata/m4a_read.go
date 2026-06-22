package metadata

import (
	"fmt"
	"os"
	"strings"
)

// ReadM4ATags reads iTunes-style metadata from an M4A file.
func ReadM4ATags(filePath string) (*AudioMetadata, error) {
	f, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	fi, err := f.Stat()
	if err != nil {
		return nil, err
	}

	ilst, err := findM4AIlstAtom(f, fi.Size())
	if err != nil {
		return nil, err
	}

	meta := &AudioMetadata{}
	start := ilst.offset + ilst.headerSize
	end := ilst.offset + ilst.size
	for pos := start; pos+8 <= end; {
		header, err := readAtomHeaderAt(f, pos, fi.Size())
		if err != nil {
			return nil, err
		}
		if header.size == 0 {
			header.size = end - pos
		}
		if header.size < header.headerSize {
			return nil, fmt.Errorf("invalid atom size for %s", header.typ)
		}

		switch header.typ {
		case "\xa9nam":
			meta.Title, _ = readM4ATextValue(f, header, fi.Size())
		case "\xa9ART":
			meta.Artist, _ = readM4ATextValue(f, header, fi.Size())
		case "\xa9alb":
			meta.Album, _ = readM4ATextValue(f, header, fi.Size())
		case "aART":
			meta.AlbumArtist, _ = readM4ATextValue(f, header, fi.Size())
		case "\xa9day":
			meta.Date, _ = readM4ATextValue(f, header, fi.Size())
			meta.Year = meta.Date
		case "\xa9gen":
			meta.Genre, _ = readM4ATextValue(f, header, fi.Size())
		case "\xa9wrt":
			meta.Composer, _ = readM4ATextValue(f, header, fi.Size())
		case "\xa9cmt":
			meta.Comment, _ = readM4ATextValue(f, header, fi.Size())
		case "cprt":
			meta.Copyright, _ = readM4ATextValue(f, header, fi.Size())
		case "\xa9lyr":
			meta.Lyrics, _ = readM4ATextValue(f, header, fi.Size())
		case "trkn":
			meta.TrackNumber, meta.TotalTracks, _ = readM4AIndexPair(f, header, fi.Size())
		case "disk":
			meta.DiscNumber, meta.TotalDiscs, _ = readM4AIndexPair(f, header, fi.Size())
		case "----":
			name, value, freeformErr := readM4AFreeformValue(f, header, fi.Size())
			if freeformErr == nil {
				switch strings.ToUpper(strings.TrimSpace(name)) {
				case "ISRC":
					meta.ISRC = value
				case "LABEL", "ORGANIZATION":
					meta.Label = value
				case "COMMENT":
					if meta.Comment == "" {
						meta.Comment = value
					}
				case "COMPOSER":
					if meta.Composer == "" {
						meta.Composer = value
					}
				case "COPYRIGHT":
					if meta.Copyright == "" {
						meta.Copyright = value
					}
				case "LYRICS", "UNSYNCEDLYRICS":
					if meta.Lyrics == "" {
						meta.Lyrics = value
					}
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
		}
		pos += header.size
	}

	if meta.Title == "" && meta.Artist == "" && meta.Album == "" &&
		meta.AlbumArtist == "" && meta.Lyrics == "" &&
		meta.TrackNumber == 0 && meta.DiscNumber == 0 {
		return nil, fmt.Errorf("no M4A tags found")
	}
	return meta, nil
}
