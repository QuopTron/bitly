package cache

import (
	"io"
	"os"
	"path/filepath"
)

// extractISRCFromMP3 reads ID3v2 tags from an MP3 file.
func extractISRCFromMP3(path string) (string, *TrackRef) {
	f, err := os.Open(path)
	if err != nil {
		return "", nil
	}
	defer f.Close()

	header := make([]byte, 10)
	if _, err := io.ReadFull(f, header); err != nil {
		return "", nil
	}

	if string(header[:3]) != "ID3" {
		return "", nil
	}

	tagSize := int(header[6])<<21 | int(header[7])<<14 | int(header[8])<<7 | int(header[9])
	if tagSize == 0 || tagSize > 10*1024*1024 { // 10MB sanity limit
		return "", nil
	}

	tagData := make([]byte, tagSize)
	if _, err := io.ReadFull(f, tagData); err != nil {
		return "", nil
	}

	return parseID3v2ForISRC(tagData, path)
}

// parseID3v2ForISRC parses ID3v2 frames looking for TSRC (ISRC) and text frames.
func parseID3v2ForISRC(data []byte, path string) (string, *TrackRef) {
	var isrc, title, artist, album string
	offset := 0

	for offset+10 <= len(data) {
		frameID := string(data[offset : offset+4])
		// ID3v2.4 uses syncsafe sizes; ID3v2.3 uses regular.
		size := int(data[offset+4])<<24 | int(data[offset+5])<<16 | int(data[offset+6])<<8 | int(data[offset+7])

		if frameID == "\x00\x00\x00\x00" || size <= 0 || offset+10+size > len(data) {
			break
		}

		frameData := data[offset+10 : offset+10+size]
		switch frameID {
		case "TSRC": // ISRC
			isrc = cleanString(frameData)
		case "TIT2": // Title
			title = cleanString(frameData)
		case "TPE1": // Artist
			artist = cleanString(frameData)
		case "TALB": // Album
			album = cleanString(frameData)
		}

		offset += 10 + size
	}

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
