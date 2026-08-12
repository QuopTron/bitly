package audio

import (
	"fmt"
	"os"
)

func extractMP3Cover(path string) (*CoverData, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	header := make([]byte, 10)
	if _, err := f.Read(header); err != nil {
		return nil, err
	}
	if string(header[:3]) != "ID3" {
		return nil, fmt.Errorf("cover: no ID3 header")
	}

	tagSize := int(header[6])<<21 | int(header[7])<<14 |
		int(header[8])<<7 | int(header[9])
	tagData := make([]byte, tagSize)
	if _, err := f.Read(tagData); err != nil {
		return nil, err
	}

	pos := 0
	for pos+10 <= len(tagData) {
		frameID := string(tagData[pos : pos+4])
		frameSize := int(tagData[pos+4])<<24 | int(tagData[pos+5])<<16 |
			int(tagData[pos+6])<<8 | int(tagData[pos+7])

		if frameID == "APIC" {
			imgStart := pos + 10
			for imgStart < len(tagData) {
				if tagData[imgStart] == 0 {
					imgStart++
					break
				}
				imgStart++
			}
			imgStart++ // skip picture type
			for imgStart < len(tagData) {
				if tagData[imgStart] == 0 {
					imgStart++
					break
				}
				imgStart++
			}
			imgEnd := pos + 10 + frameSize
			if imgEnd > len(tagData) {
				imgEnd = len(tagData)
			}

			mimeType := "image/jpeg"
			if len(tagData) > pos+14 {
				mimeStr := string(tagData[pos+11 : pos+20])
				if len(mimeStr) >= 3 && mimeStr[:3] == "png" {
					mimeType = "image/png"
				}
			}
			return &CoverData{Data: tagData[imgStart:imgEnd], MimeType: mimeType}, nil
		}
		pos += 10 + frameSize
	}
	return nil, fmt.Errorf("cover: no APIC frame found")
}
