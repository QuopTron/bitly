package cache

import (
	"encoding/binary"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// extractISRCFromFile reads an audio file and extracts the ISRC code.
func extractISRCFromFile(path string) (string, *TrackRef) {
	ext := strings.ToLower(filepath.Ext(path))
	switch ext {
	case ".flac":
		return extractISRCFromFLAC(path)
	case ".mp3":
		return extractISRCFromMP3(path)
	case ".m4a", ".mp4", ".m4b":
		return extractISRCFromM4A(path)
	case ".ogg", ".opus":
		return extractISRCFromOGG(path)
	}
	return "", nil
}

// extractISRCFromFLAC reads Vorbis comments from a FLAC file to find ISRC.
func extractISRCFromFLAC(path string) (string, *TrackRef) {
	f, err := os.Open(path)
	if err != nil {
		return "", nil
	}
	defer f.Close()

	// Verify FLAC header
	header := make([]byte, 4)
	if _, err := io.ReadFull(f, header); err != nil || string(header) != "fLaC" {
		return "", nil
	}

	// Walk metadata blocks looking for Vorbis comment (type 4)
	for {
		blockHeader := make([]byte, 4)
		if _, err := io.ReadFull(f, blockHeader); err != nil {
			return "", nil
		}
		isLast := blockHeader[0]&0x80 != 0
		blockType := blockHeader[0] & 0x7F
		blockSize := int(blockHeader[1])<<16 | int(blockHeader[2])<<8 | int(blockHeader[3])

		if blockType == 4 { // Vorbis comment
			return parseVorbisCommentsForISRC(f, blockSize, path)
		}

		if isLast {
			break
		}
		// Skip this block
		if _, err := io.CopyN(io.Discard, f, int64(blockSize)); err != nil {
			return "", nil
		}
	}
	return "", nil
}

// parseVorbisCommentsForISRC parses a Vorbis comment block for ISRC metadata.
func parseVorbisCommentsForISRC(r io.Reader, blockSize int, path string) (string, *TrackRef) {
	data := make([]byte, blockSize)
	if _, err := io.ReadFull(r, data); err != nil {
		return "", nil
	}

	if len(data) < 8 {
		return "", nil
	}

	// Vendor string length (LE uint32)
	vendorLen := int(binary.LittleEndian.Uint32(data[0:4]))
	offset := 4 + vendorLen
	if offset >= len(data) {
		return "", nil
	}

	// Number of comment entries
	numComments := int(binary.LittleEndian.Uint32(data[offset : offset+4]))
	offset += 4

	var isrc, title, artist, album string
	for i := 0; i < numComments && offset < len(data); i++ {
		if offset+4 > len(data) {
			break
		}
		entryLen := int(binary.LittleEndian.Uint32(data[offset : offset+4]))
		offset += 4
		if offset+entryLen > len(data) {
			break
		}
		entry := string(data[offset : offset+entryLen])
		offset += entryLen

		eqIdx := strings.Index(entry, "=")
		if eqIdx < 0 {
			continue
		}
		key := strings.ToUpper(entry[:eqIdx])
		val := entry[eqIdx+1:]

		switch key {
		case "ISRC":
			isrc = strings.TrimSpace(val)
		case "TITLE":
			title = val
		case "ARTIST":
			artist = val
		case "ALBUM":
			album = val
		}
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
