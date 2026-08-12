package audio

import (
	"bytes"
	"fmt"
	"os"
)

func extractMP4Cover(path string) (*CoverData, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	for i := 0; i < len(data)-8; i++ {
		if data[i] == 'c' && data[i+1] == 'o' && data[i+2] == 'v' && data[i+3] == 'r' {
			imgStart := i + 16
			if imgStart+4 > len(data) {
				break
			}
			if data[imgStart] == 0xFF && data[imgStart+1] == 0xD8 {
				imgEnd := bytes.LastIndex(data[imgStart:], []byte{0xFF, 0xD9})
				if imgEnd > 0 {
					return &CoverData{
						Data:     data[imgStart : imgStart+imgEnd+2],
						MimeType: "image/jpeg",
					}, nil
				}
			}
			if data[imgStart] == 0x89 && data[imgStart+1] == 0x50 {
				imgEnd := bytes.LastIndex(data[imgStart:], []byte{0x49, 0x45, 0x4E, 0x44})
				if imgEnd > 0 {
					return &CoverData{
						Data:     data[imgStart : imgStart+imgEnd+4],
						MimeType: "image/png",
					}, nil
				}
			}
			break
		}
	}
	return nil, fmt.Errorf("cover: no covr atom found in MP4")
}
