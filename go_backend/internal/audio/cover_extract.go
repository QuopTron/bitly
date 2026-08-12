package audio

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// ExtractCover reads cover art from an audio file.
func ExtractCover(filePath string) (*CoverData, error) {
	ext := strings.ToLower(filepath.Ext(filePath))
	switch ext {
	case ".flac":
		return extractFLACCover(filePath)
	case ".mp3":
		return extractMP3Cover(filePath)
	case ".m4a", ".mp4":
		return extractMP4Cover(filePath)
	default:
		return nil, fmt.Errorf("cover: unsupported format %s", ext)
	}
}

func extractFLACCover(path string) (*CoverData, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	data := make([]byte, 1024*1024)
	n, err := f.Read(data)
	if err != nil {
		return nil, err
	}
	data = data[:n]

	pos := 4
	for pos+4 < len(data) {
		isLast := data[pos] & 0x80
		blockType := data[pos] & 0x7F
		blockSize := int(data[pos+1])<<16 | int(data[pos+2])<<8 | int(data[pos+3])
		pos += 4

		if blockType == 6 {
			imgStart := pos
			if bytes.HasPrefix(data[pos:], []byte{0xFF, 0xD8}) {
				imgEnd := bytes.LastIndex(data, []byte{0xFF, 0xD9})
				if imgEnd > imgStart {
					return &CoverData{Data: data[imgStart : imgEnd+2], MimeType: "image/jpeg"}, nil
				}
			}
			if bytes.HasPrefix(data[pos:], []byte{0x89, 0x50, 0x4E, 0x47}) {
				imgEnd := bytes.LastIndex(data, []byte{0x49, 0x45, 0x4E, 0x44})
				if imgEnd > imgStart {
					return &CoverData{Data: data[imgStart : imgEnd+4], MimeType: "image/png"}, nil
				}
			}
		}
		pos += blockSize
		if isLast != 0 {
			break
		}
	}
	return nil, fmt.Errorf("cover: no cover found in FLAC")
}
