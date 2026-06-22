package metadata

import (
	"fmt"
	"io"
	"os"
)

// ReadOggVorbisComments reads Vorbis Comments from Ogg/Opus files.
func ReadOggVorbisComments(filePath string) (*AudioMetadata, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	meta := &AudioMetadata{}

	packets, err := collectOggPackets(file, 30, 80)
	if err != nil && len(packets) == 0 {
		return nil, err
	}

	streamType := detectOggStreamType(packets)
	for _, pkt := range packets {
		if streamType == oggStreamOpus {
			if len(pkt) > 8 && string(pkt[0:8]) == "OpusTags" {
				parseVorbisComments(pkt[8:], meta)
				break
			}
			continue
		}
		if streamType == oggStreamVorbis || streamType == oggStreamUnknown {
			if len(pkt) > 7 && pkt[0] == 0x03 && string(pkt[1:7]) == "vorbis" {
				parseVorbisComments(pkt[7:], meta)
				break
			}
		}
		if streamType == oggStreamUnknown {
			if len(pkt) > 8 && string(pkt[0:8]) == "OpusTags" {
				parseVorbisComments(pkt[8:], meta)
				break
			}
		}
	}

	if meta.Title == "" && meta.Artist == "" {
		return nil, fmt.Errorf("no Vorbis comments found")
	}
	return meta, nil
}

type oggPage struct {
	headerType   byte
	segmentTable []byte
	data         []byte
}

func readOggPageWithHeader(file *os.File) (*oggPage, error) {
	header := make([]byte, 27)
	if _, err := io.ReadFull(file, header); err != nil {
		return nil, err
	}
	if string(header[0:4]) != "OggS" {
		return nil, fmt.Errorf("not an Ogg page")
	}
	headerType := header[5]
	numSegments := int(header[26])
	segmentTable := make([]byte, numSegments)
	if _, err := io.ReadFull(file, segmentTable); err != nil {
		return nil, err
	}
	var pageSize int
	for _, seg := range segmentTable {
		pageSize += int(seg)
	}
	pageData := make([]byte, pageSize)
	if _, err := io.ReadFull(file, pageData); err != nil {
		return nil, err
	}
	return &oggPage{headerType: headerType, segmentTable: segmentTable, data: pageData}, nil
}
