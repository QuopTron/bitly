package audio

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// WriteCover embeds cover art into an audio file.
// Supported formats: FLAC, MP3, M4A.
func WriteCover(filePath string, coverData []byte) error {
	ext := strings.ToLower(filepath.Ext(filePath))
	switch ext {
	case ".flac":
		return writeFLACCover(filePath, coverData)
	case ".mp3":
		return writeMP3Cover(filePath, coverData)
	case ".m4a", ".mp4":
		return writeMP4Cover(filePath, coverData)
	default:
		return fmt.Errorf("cover: unsupported format %s for writing", ext)
	}
}

func writeFLACCover(filePath string, coverData []byte) error {
	f, err := os.ReadFile(filePath)
	if err != nil {
		return err
	}
	if len(f) < 4 || string(f[:4]) != "fLaC" {
		return fmt.Errorf("cover: not a FLAC file")
	}

	mimeType := detectMIME(coverData)
	var picBlock bytes.Buffer
	writeBE32(&picBlock, 3) // picture type: Front Cover
	writeBE32(&picBlock, uint32(len(mimeType)))
	picBlock.WriteString(mimeType)
	writeBE32(&picBlock, 0) // description length (empty)
	writeBE32(&picBlock, 0) // width
	writeBE32(&picBlock, 0) // height
	writeBE32(&picBlock, 0) // color depth
	writeBE32(&picBlock, 0) // colors used
	writeBE32(&picBlock, uint32(len(coverData)))
	picBlock.Write(coverData)

	picData := picBlock.Bytes()
	var blockHeader [4]byte
	blockHeader[0] = 6 // PICTURE
	blockHeader[1] = byte(len(picData) >> 16)
	blockHeader[2] = byte(len(picData) >> 8)
	blockHeader[3] = byte(len(picData))

	pos := 4
	firstBlockLen := int(f[pos+1])<<16 | int(f[pos+2])<<8 | int(f[pos+3])
	insertPos := pos + 4 + firstBlockLen

	var out bytes.Buffer
	out.Write(f[:pos])
	firstHeader := make([]byte, 4)
	copy(firstHeader, f[pos:pos+4])
	firstHeader[0] &^= 0x80
	out.Write(firstHeader)
	out.Write(f[pos+4 : pos+4+firstBlockLen])
	out.Write(blockHeader[:])
	out.Write(picData)
	out.Write(f[insertPos:])
	return os.WriteFile(filePath, out.Bytes(), 0644)
}
