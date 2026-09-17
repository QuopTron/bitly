package audio

import (
	"bytes"
	"encoding/binary"
)

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
