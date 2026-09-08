package cache

import (
	"os"
	"path/filepath"
)

// extractISRCFromM4A reads MP4/iTunes metadata for ISRC.
func extractISRCFromM4A(path string) (string, *TrackRef) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", nil
	}
	return parseMP4AtomsForISRC(data, path)
}

// parseMP4AtomsForISRC walks MP4 atoms to find ©ISRC or trkn metadata.
func parseMP4AtomsForISRC(data []byte, path string) (string, *TrackRef) {
	if len(data) < 8 {
		return "", nil
	}

	var isrc, title, artist, album string

	var walk func(offset, end int)
	walk = func(offset, end int) {
		for offset+8 <= end {
			size := int(data[offset])<<24 | int(data[offset+1])<<16 | int(data[offset+2])<<8 | int(data[offset+3])
			atomType := string(data[offset+4 : offset+8])
			if size < 8 || offset+size > end {
				break
			}

			switch atomType {
			case "©ISRC", "isrc":
				isrc = cleanString(data[offset+8 : offset+size])
			case "©nam", "name":
				title = cleanString(data[offset+8 : offset+size])
			case "©ART", "ART":
				artist = cleanString(data[offset+8 : offset+size])
			case "©alb", "alb":
				album = cleanString(data[offset+8 : offset+size])
			case "moov", "udta", "meta", "ilst":
				walk(offset+8, offset+size)
			}

			offset += size
		}
	}

	walk(0, len(data))
	if isrc == "" {
		return "", nil
	}
	return isrc, &TrackRef{
		Title:      title,
		ArtistName: artist,
		AlbumName:  album,
		TrackID:    filepath.Base(path),
	}
}
