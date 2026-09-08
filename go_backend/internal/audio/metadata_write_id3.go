package audio

import (
	"bytes"
	"encoding/binary"
)

func construirFrameID3(frameID, value string) []byte {
	// ID3v2.4 text frame: frameID(4) + size(4) + flags(2) + encoding(1) + text
	text := []byte(value)
	size := len(text) + 1 // +1 for encoding byte
	var buf bytes.Buffer
	buf.WriteString(frameID)
	binary.Write(&buf, binary.BigEndian, uint32(size))
	binary.Write(&buf, binary.BigEndian, uint16(0)) // flags
	buf.WriteByte(0)                                // UTF-8 encoding
	buf.Write(text)
	return buf.Bytes()
}

func construirCabeceraID3v2(tagSize int) []byte {
	// ID3v2.4 header: "ID3" + version(2) + flags(1) + size(4, synchsafe)
	header := make([]byte, 10)
	copy(header[0:3], "ID3")
	header[3] = 4 // version 2.4
	header[4] = 0 // revision
	header[5] = 0 // flags

	// Synchsafe integer encoding
	size := tagSize
	header[6] = byte(size >> 21)
	header[7] = byte(size >> 14)
	header[8] = byte(size >> 7)
	header[9] = byte(size)
	return header
}

// ─── Metadata Language / Accept-Language ──────────────────────────────
