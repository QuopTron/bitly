package metadata

import (
	"fmt"
	"io"
	"os"
	"strings"
)

func readID3v2(file *os.File) (*AudioMetadata, error) {
	file.Seek(0, io.SeekStart)
	header := make([]byte, 10)
	if _, err := io.ReadFull(file, header); err != nil {
		return nil, err
	}
	if string(header[0:3]) != "ID3" {
		return nil, fmt.Errorf("no ID3v2 header")
	}

	majorVersion := header[3]
	flags := header[5]
	unsync := (flags & 0x80) != 0
	extendedHeader := (flags & 0x40) != 0
	footerPresent := (flags & 0x10) != 0

	size := int(header[6])<<21 | int(header[7])<<14 | int(header[8])<<7 | int(header[9])
	tagData := make([]byte, size)
	if _, err := io.ReadFull(file, tagData); err != nil {
		return nil, err
	}
	if footerPresent && len(tagData) >= 10 {
		footerStart := len(tagData) - 10
		if footerStart >= 0 && string(tagData[footerStart:footerStart+3]) == "3DI" {
			tagData = tagData[:footerStart]
		}
	}
	if extendedHeader {
		if skip := extendedHeaderSize(tagData, majorVersion); skip > 0 && skip < len(tagData) {
			tagData = tagData[skip:]
		}
	}

	meta := &AudioMetadata{}
	if majorVersion == 2 {
		parseID3v22Frames(tagData, meta, unsync)
	} else {
		parseID3v23Frames(tagData, meta, majorVersion, unsync)
	}
	return meta, nil
}

func readID3v1(file *os.File) (*AudioMetadata, error) {
	if _, err := file.Seek(-128, io.SeekEnd); err != nil {
		return nil, err
	}
	tag := make([]byte, 128)
	if _, err := io.ReadFull(file, tag); err != nil {
		return nil, err
	}
	if string(tag[0:3]) != "TAG" {
		return nil, fmt.Errorf("no ID3v1 tag")
	}
	meta := &AudioMetadata{
		Title:  strings.TrimRight(string(tag[3:33]), " \x00"),
		Artist: strings.TrimRight(string(tag[33:63]), " \x00"),
		Album:  strings.TrimRight(string(tag[63:93]), " \x00"),
		Year:   strings.TrimRight(string(tag[93:97]), " \x00"),
	}
	if tag[125] == 0 && tag[126] != 0 {
		meta.TrackNumber = int(tag[126])
	}
	genreIndex := int(tag[127])
	if genreIndex < len(ID3v1Genres) {
		meta.Genre = ID3v1Genres[genreIndex]
	}
	return meta, nil
}
