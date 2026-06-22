package metadata

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
	"os"
	"strings"
)

// ExtractOggCoverArt extracts cover art from Ogg/Opus files.
func ExtractOggCoverArt(filePath string) ([]byte, string, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, "", err
	}
	defer file.Close()

	packets, err := collectOggPackets(file, 30, 80)
	if err != nil && len(packets) == 0 {
		return nil, "", err
	}

	streamType := detectOggStreamType(packets)
	for _, pkt := range packets {
		var comments []byte
		if streamType == oggStreamOpus {
			if len(pkt) > 8 && string(pkt[0:8]) == "OpusTags" {
				comments = pkt[8:]
			}
		} else {
			if len(pkt) > 7 && pkt[0] == 0x03 && string(pkt[1:7]) == "vorbis" {
				comments = pkt[7:]
			}
		}
		if len(comments) == 0 && streamType == oggStreamUnknown {
			if len(pkt) > 8 && string(pkt[0:8]) == "OpusTags" {
				comments = pkt[8:]
			} else if len(pkt) > 7 && pkt[0] == 0x03 && string(pkt[1:7]) == "vorbis" {
				comments = pkt[7:]
			}
		}
		if len(comments) > 0 {
			imageData, mimeType := extractPictureFromVorbisComments(comments)
			if len(imageData) > 0 {
				return imageData, mimeType, nil
			}
		}
	}
	return nil, "", fmt.Errorf("no cover art found")
}

func extractPictureFromVorbisComments(data []byte) ([]byte, string) {
	if len(data) < 8 {
		return nil, ""
	}
	reader := bytes.NewReader(data)
	var vendorLen uint32
	if err := binary.Read(reader, binary.LittleEndian, &vendorLen); err != nil {
		return nil, ""
	}
	if vendorLen > uint32(len(data)-4) {
		return nil, ""
	}
	reader.Seek(int64(vendorLen), io.SeekCurrent)

	var commentCount uint32
	if err := binary.Read(reader, binary.LittleEndian, &commentCount); err != nil {
		return nil, ""
	}
	for i := uint32(0); i < commentCount && i < 100; i++ {
		var commentLen uint32
		if err := binary.Read(reader, binary.LittleEndian, &commentLen); err != nil {
			break
		}
		if commentLen > 10000000 {
			break
		}
		comment := make([]byte, commentLen)
		if _, err := reader.Read(comment); err != nil {
			break
		}
		key := "METADATA_BLOCK_PICTURE="
		if len(comment) > len(key) && strings.ToUpper(string(comment[:len(key)])) == key {
			b64Data := comment[len(key):]
			decoded := make([]byte, base64StdDecodeLen(len(b64Data)))
			n, err := base64StdDecode(decoded, b64Data)
			if err != nil {
				continue
			}
			decoded = decoded[:n]
			imageData, mimeType := parseFLACPictureBlock(decoded)
			if len(imageData) > 0 {
				return imageData, mimeType
			}
		}
	}
	return nil, ""
}
