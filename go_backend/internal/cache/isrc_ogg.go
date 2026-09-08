package cache

import (
	"encoding/binary"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// extractISRCFromOGG reads Vorbis comments from OGG/Opus files.
func extractISRCFromOGG(path string) (string, *TrackRef) {
	f, err := os.Open(path)
	if err != nil {
		return "", nil
	}
	defer f.Close()

	// OGG page header
	header := make([]byte, 28)
	if _, err := io.ReadFull(f, header); err != nil {
		return "", nil
	}
	if string(header[:4]) != "OggS" {
		return "", nil
	}

	// For OGG, the first page contains the Vorbis/Opus header.
	// The comment página follows. We leer el primero página's segment table
	// to skip it, then parse the next page's comments.
	numSegments := int(header[26])
	if numSegments == 0 {
		return "", nil
	}
	segTable := make([]byte, numSegments)
	if _, err := io.ReadFull(f, segTable); err != nil {
		return "", nil
	}
	pageSize := 0
	for _, s := range segTable {
		pageSize += int(s)
	}
	// Skip first page data
	if _, err := io.CopyN(io.Discard, f, int64(pageSize)); err != nil {
		return "", nil
	}

	// Read second page header
	if _, err := io.ReadFull(f, header); err != nil {
		return "", nil
	}
	numSegments = int(header[26])
	segTable = make([]byte, numSegments)
	if _, err := io.ReadFull(f, segTable); err != nil {
		return "", nil
	}
	pageSize = 0
	for _, s := range segTable {
		pageSize += int(s)
	}
	pageData := make([]byte, pageSize)
	if _, err := io.ReadFull(f, pageData); err != nil {
		return "", nil
	}

	// Skip Vorbis/Opus header bytes in comment block
	// Vorbis: 7 bytes header + vendor string
	if len(pageData) < 7 {
		return "", nil
	}
	offset := 7
	if offset+4 > len(pageData) {
		return "", nil
	}
	vendorLen := int(binary.LittleEndian.Uint32(pageData[offset : offset+4]))
	offset += 4 + vendorLen
	if offset+4 > len(pageData) {
		return "", nil
	}
	numComments := int(binary.LittleEndian.Uint32(pageData[offset : offset+4]))
	offset += 4

	for i := 0; i < numComments && offset < len(pageData); i++ {
		if offset+4 > len(pageData) {
			break
		}
		entryLen := int(binary.LittleEndian.Uint32(pageData[offset : offset+4]))
		offset += 4
		if offset+entryLen > len(pageData) {
			break
		}
		entry := string(pageData[offset : offset+entryLen])
		offset += entryLen

		eqIdx := strings.Index(entry, "=")
		if eqIdx < 0 {
			continue
		}
		key := strings.ToUpper(entry[:eqIdx])
		val := entry[eqIdx+1:]

		if key == "ISRC" {
			isrc := strings.TrimSpace(val)
			if isrc != "" {
				return isrc, &TrackRef{TrackID: filepath.Base(path)}
			}
		}
	}
	return "", nil
}
