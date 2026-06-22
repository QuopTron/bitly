package metadata

import (
	"encoding/binary"
	"fmt"
	"os"
)

func readAPETagAtOffset(f *os.File, fileSize, footerOffset int64) (*APETag, error) {
	if footerOffset < 0 || footerOffset+apeTagHeaderSize > fileSize {
		return nil, fmt.Errorf("invalid footer offset")
	}

	footer := make([]byte, apeTagHeaderSize)
	if _, err := f.ReadAt(footer, footerOffset); err != nil {
		return nil, fmt.Errorf("failed to read APE footer: %w", err)
	}

	if string(footer[0:8]) != apeTagPreamble {
		return nil, fmt.Errorf("APE preamble not found")
	}

	version := binary.LittleEndian.Uint32(footer[8:12])
	tagSize := binary.LittleEndian.Uint32(footer[12:16])
	itemCount := binary.LittleEndian.Uint32(footer[16:20])
	flags := binary.LittleEndian.Uint32(footer[20:24])

	if version != apeTagVersion2 && version != 1000 {
		return nil, fmt.Errorf("unsupported APE tag version: %d", version)
	}
	if tagSize < apeTagHeaderSize {
		return nil, fmt.Errorf("APE tag size too small: %d", tagSize)
	}
	if itemCount > 1000 {
		return nil, fmt.Errorf("APE tag item count too large: %d", itemCount)
	}

	isHeader := (flags & apeTagFlagHeader) != 0
	if isHeader {
		return nil, fmt.Errorf("expected APE footer but found header")
	}

	itemsSize := int64(tagSize) - apeTagHeaderSize
	if itemsSize < 0 {
		return nil, fmt.Errorf("invalid APE tag: items size negative")
	}

	itemsOffset := footerOffset - itemsSize
	if itemsOffset < 0 {
		return nil, fmt.Errorf("APE tag items extend before file start")
	}

	itemsData := make([]byte, itemsSize)
	if _, err := f.ReadAt(itemsData, itemsOffset); err != nil {
		return nil, fmt.Errorf("failed to read APE items: %w", err)
	}

	items, err := parseAPEItems(itemsData, int(itemCount))
	if err != nil {
		return nil, fmt.Errorf("failed to parse APE items: %w", err)
	}

	return &APETag{
		Version:  version,
		Items:    items,
		ReadOnly: (flags & apeTagFlagReadOnly) != 0,
	}, nil
}

func parseAPEItems(data []byte, count int) ([]APETagItem, error) {
	items := make([]APETagItem, 0, count)
	pos := 0

	for i := 0; i < count && pos < len(data); i++ {
		if pos+8 > len(data) {
			break
		}
		valueSize := int(binary.LittleEndian.Uint32(data[pos : pos+4]))
		itemFlags := binary.LittleEndian.Uint32(data[pos+4 : pos+8])
		pos += 8

		keyEnd := pos
		for keyEnd < len(data) && data[keyEnd] != 0 {
			keyEnd++
		}
		if keyEnd >= len(data) {
			break
		}
		key := string(data[pos:keyEnd])
		pos = keyEnd + 1

		if pos+valueSize > len(data) {
			break
		}
		value := string(data[pos : pos+valueSize])
		pos += valueSize

		items = append(items, APETagItem{
			Key:   key,
			Value: value,
			Flags: itemFlags,
		})
	}
	return items, nil
}
