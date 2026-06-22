package metadata

import (
	"fmt"
	"io"
	"os"
)

// ExtractMP3CoverArt extracts cover art from an MP3 file.
func ExtractMP3CoverArt(filePath string) ([]byte, string, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, "", err
	}
	defer file.Close()

	header := make([]byte, 10)
	if _, err := io.ReadFull(file, header); err != nil {
		return nil, "", err
	}
	if string(header[0:3]) != "ID3" {
		return nil, "", fmt.Errorf("no ID3v2 header")
	}

	majorVersion := header[3]
	size := int(header[6])<<21 | int(header[7])<<14 | int(header[8])<<7 | int(header[9])
	tagData := make([]byte, size)
	if _, err := io.ReadFull(file, tagData); err != nil {
		return nil, "", err
	}

	pos := 0
	var frameIDLen, headerLen int
	if majorVersion == 2 {
		frameIDLen, headerLen = 3, 6
	} else {
		frameIDLen, headerLen = 4, 10
	}

	for pos+headerLen < len(tagData) {
		frameID := string(tagData[pos : pos+frameIDLen])
		if frameID[0] == 0 {
			break
		}
		var frameSize int
		if majorVersion == 2 {
			frameSize = int(tagData[pos+3])<<16 | int(tagData[pos+4])<<8 | int(tagData[pos+5])
		} else if majorVersion == 4 {
			frameSize = int(tagData[pos+4])<<21 | int(tagData[pos+5])<<14 | int(tagData[pos+6])<<7 | int(tagData[pos+7])
		} else {
			frameSize = int(tagData[pos+4])<<24 | int(tagData[pos+5])<<16 | int(tagData[pos+6])<<8 | int(tagData[pos+7])
		}
		if frameSize <= 0 || pos+headerLen+frameSize > len(tagData) {
			break
		}
		if (frameIDLen == 4 && frameID == "APIC") || (frameIDLen == 3 && frameID == "PIC") {
			frameData := tagData[pos+headerLen : pos+headerLen+frameSize]
			imageData, mimeType := parseAPICFrame(frameData, majorVersion)
			if len(imageData) > 0 {
				return imageData, mimeType, nil
			}
		}
		pos += headerLen + frameSize
	}
	return nil, "", fmt.Errorf("no cover art found")
}

func parseAPICFrame(data []byte, version byte) ([]byte, string) {
	if len(data) < 4 {
		return nil, ""
	}
	pos := 0
	encoding := data[pos]
	pos++

	var mimeType string
	if version == 2 {
		if pos+3 > len(data) {
			return nil, ""
		}
		format := string(data[pos : pos+3])
		pos += 3
		switch format {
		case "JPG":
			mimeType = "image/jpeg"
		case "PNG":
			mimeType = "image/png"
		default:
			mimeType = "image/jpeg"
		}
	} else {
		end := pos
		for end < len(data) && data[end] != 0 {
			end++
		}
		mimeType = string(data[pos:end])
		pos = end + 1
	}
	if pos >= len(data) {
		return nil, ""
	}
	pos++

	if encoding == 0 || encoding == 3 {
		for pos < len(data) && data[pos] != 0 {
			pos++
		}
		pos++
	} else {
		for pos+1 < len(data) {
			if data[pos] == 0 && data[pos+1] == 0 {
				pos += 2
				break
			}
			pos++
		}
	}
	if pos >= len(data) {
		return nil, ""
	}
	return data[pos:], mimeType
}
