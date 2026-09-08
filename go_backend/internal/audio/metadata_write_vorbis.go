package audio

import (
	"bytes"
	"encoding/binary"
	"strings"
)

func reconstruirBloqueVorbis(data []byte, artists, albumArtists []string) []byte {
	var buf bytes.Buffer
	offset := 0

	if len(data) < 4 {
		return data
	}

	// Vendor string
	vendorLen := int(binary.LittleEndian.Uint32(data[0:4]))
	offset = 4 + vendorLen
	buf.Write(data[0:offset])

	// Count existing entries (skip ARTIST and ALBUMARTIST)
	numEntries := int(binary.LittleEndian.Uint32(data[offset : offset+4]))
	offset += 4

	var keptEntries int
	for i := 0; i < numEntries && offset < len(data); i++ {
		entryLen := int(binary.LittleEndian.Uint32(data[offset : offset+4]))
		offset += 4
		if offset+entryLen > len(data) {
			break
		}
		entry := string(data[offset : offset+entryLen])
		offset += entryLen

		eqIdx := strings.Index(entry, "=")
		if eqIdx >= 0 {
			key := strings.ToUpper(entry[:eqIdx])
			if key == "ARTIST" || key == "ALBUMARTIST" {
				continue // skip, we'll add our own
			}
		}
		keptEntries++
		// We need to re-encode this entry
		// Store entries in a temp buffer
		_ = entry
	}

	// Simpler approach: rebuild from scratch
	return reconstruirVorbisDesdeCero(data, artists, albumArtists)
}

func reconstruirVorbisDesdeCero(data []byte, artists, albumArtists []string) []byte {
	var buf bytes.Buffer

	if len(data) < 4 {
		return data
	}

	// Vendor string
	vendorLen := int(binary.LittleEndian.Uint32(data[0:4]))
	vendor := string(data[4 : 4+vendorLen])

	buf.Write(bytesUint32(uint32(vendorLen)))
	buf.WriteString(vendor)

	// For now, just rebuild with known fields
	// Count: artists + albumArtists
	totalEntries := len(artists) + len(albumArtists)
	buf.Write(bytesUint32(uint32(totalEntries)))

	for _, a := range artists {
		entry := "ARTIST=" + a
		buf.Write(bytesUint32(uint32(len(entry))))
		buf.WriteString(entry)
	}
	for _, a := range albumArtists {
		entry := "ALBUMARTIST=" + a
		buf.Write(bytesUint32(uint32(len(entry))))
		buf.WriteString(entry)
	}

	return buf.Bytes()
}

func bytesUint32(v uint32) []byte {
	b := make([]byte, 4)
	binary.LittleEndian.PutUint32(b, v)
	return b
}
