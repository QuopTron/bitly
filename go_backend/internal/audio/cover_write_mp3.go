package audio

import (
	"bytes"
	"os"
)

func writeMP3Cover(filePath string, coverData []byte) error {
	f, err := os.ReadFile(filePath)
	if err != nil {
		return err
	}
	if len(f) < 10 || string(f[:3]) != "ID3" {
		return prependID3WithCover(filePath, coverData)
	}

	tagSize := int(f[6])<<21 | int(f[7])<<14 | int(f[8])<<7 | int(f[9])
	tagEnd := 10 + tagSize

	mimeBytes := []byte(detectMIME(coverData))
	picData := buildAPICFrameData(mimeBytes, coverData)

	apicPos := findAPICFrame(f[10:tagEnd])
	var newTag []byte
	if apicPos >= 0 {
		frameStart := 10 + apicPos
		oldFrameSize := int(f[frameStart+4])<<24 | int(f[frameStart+5])<<16 |
			int(f[frameStart+6])<<8 | int(f[frameStart+7])
		frameEnd := frameStart + 10 + oldFrameSize
		newTag = append(newTag, f[10:frameStart]...)
		newTag = append(newTag, picData...)
		newTag = append(newTag, f[frameEnd:tagEnd]...)
	} else {
		newTag = append([]byte{}, f[10:tagEnd]...)
		newTag = append(newTag, picData...)
	}

	newTagSize := len(newTag)
	f[6] = byte(newTagSize >> 21 & 0x7F)
	f[7] = byte(newTagSize >> 14 & 0x7F)
	f[8] = byte(newTagSize >> 7 & 0x7F)
	f[9] = byte(newTagSize & 0x7F)

	var out bytes.Buffer
	out.Write(f[:10])
	out.Write(newTag)
	out.Write(f[tagEnd:])
	return os.WriteFile(filePath, out.Bytes(), 0644)
}

func prependID3WithCover(filePath string, coverData []byte) error {
	mimeBytes := []byte(detectMIME(coverData))
	picData := buildAPICFrameData(mimeBytes, coverData)
	tagSize := len(picData)

	var header [10]byte
	header[0], header[1], header[2] = 'I', 'D', '3'
	header[3], header[4] = 3, 0
	header[6] = byte(tagSize >> 21 & 0x7F)
	header[7] = byte(tagSize >> 14 & 0x7F)
	header[8] = byte(tagSize >> 7 & 0x7F)
	header[9] = byte(tagSize & 0x7F)

	f, err := os.ReadFile(filePath)
	if err != nil {
		return err
	}
	var out bytes.Buffer
	out.Write(header[:])
	out.Write(picData)
	out.Write(f)
	return os.WriteFile(filePath, out.Bytes(), 0644)
}
