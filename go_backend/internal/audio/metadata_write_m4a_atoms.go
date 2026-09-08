package audio

import (
	"bytes"
	"encoding/binary"
)

func inyectarFreeformEnUdta(udtaAtom []byte, tags map[string]string) []byte {
	var buf bytes.Buffer
	buf.Write(udtaAtom[:8]) // keep header

	offset := 8
	for offset < len(udtaAtom) {
		if offset+8 > len(udtaAtom) {
			buf.Write(udtaAtom[offset:])
			break
		}
		atomSize := int(udtaAtom[offset])<<24 | int(udtaAtom[offset+1])<<16 | int(udtaAtom[offset+2])<<8 | int(udtaAtom[offset+3])
		if atomSize < 8 || offset+atomSize > len(udtaAtom) {
			buf.Write(udtaAtom[offset:])
			break
		}
		buf.Write(udtaAtom[offset : offset+atomSize])
		offset += atomSize
	}

	// Append freeform atoms
	for key, value := range tags {
		if value == "" {
			continue
		}
		freeAtom := construirAtomoFreeform(key, value)
		buf.Write(freeAtom)
	}

	// Update size
	size := buf.Len()
	out := buf.Bytes()
	out[0] = byte(size >> 24)
	out[1] = byte(size >> 16)
	out[2] = byte(size >> 8)
	out[3] = byte(size)

	return out
}

func construirAtomoFreeform(key, value string) []byte {
	// iTunes freeform: ----:com.apple.iTunes:KEY
	atomKey := "----:com.apple.iTunes:" + key
	var buf bytes.Buffer

	// Placeholder for atom size
	buf.Write([]byte{0, 0, 0, 0})
	buf.WriteString(atomKey)
	buf.WriteByte(0) // null terminator

	// Data atom
	dataAtom := construirAtomoDatosM4A(value)
	buf.Write(dataAtom)

	data := buf.Bytes()
	size := len(data)
	binary.BigEndian.PutUint32(data[0:4], uint32(size))
	return data
}

func construirAtomoDatosM4A(value string) []byte {
	var buf bytes.Buffer
	buf.WriteString("data")
	// Type indicator: 1 = UTF-8
	binary.Write(&buf, binary.BigEndian, uint32(1))
	// Locale: 0
	binary.Write(&buf, binary.BigEndian, uint32(0))
	// Value
	buf.WriteString(value)

	data := buf.Bytes()
	// Update size
	size := len(data)
	binary.BigEndian.PutUint32(data[0:4], uint32(size))
	return data
}

// ─── Split Artist Tag Rewriting ───────────────────────────────────────

// RewriteSplitArtistTags rewrites Vorbis comment ARTIST and ALBUMARTIST as
// multiple separate entries, fixing FFmpeg's deduplication behavior.
