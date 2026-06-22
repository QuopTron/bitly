package metadata

import (
	"encoding/binary"
	"fmt"
	"os"
)

// WriteAPETags writes APEv2 tags to the end of a file.
func WriteAPETags(filePath string, tag *APETag) error {
	existingSize, err := findExistingAPETagSize(filePath)
	if err != nil {
		return fmt.Errorf("failed to check existing APE tag: %w", err)
	}

	tagData, err := marshalAPETag(tag)
	if err != nil {
		return fmt.Errorf("failed to marshal APE tag: %w", err)
	}

	if existingSize > 0 {
		fi, err := os.Stat(filePath)
		if err != nil {
			return fmt.Errorf("failed to stat file: %w", err)
		}
		newSize := fi.Size() - int64(existingSize)
		if err := os.Truncate(filePath, newSize); err != nil {
			return fmt.Errorf("failed to truncate existing APE tag: %w", err)
		}
	}

	f, err := os.OpenFile(filePath, os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		return fmt.Errorf("failed to open file for writing: %w", err)
	}
	defer f.Close()

	if _, err := f.Write(tagData); err != nil {
		return fmt.Errorf("failed to write APE tag: %w", err)
	}
	return nil
}

func findExistingAPETagSize(filePath string) (int64, error) {
	f, err := os.Open(filePath)
	if err != nil {
		return 0, err
	}
	defer f.Close()

	fi, err := f.Stat()
	if err != nil {
		return 0, err
	}
	fileSize := fi.Size()

	offsets := []int64{fileSize - apeTagHeaderSize}
	if fileSize > apeTagHeaderSize+128 {
		offsets = append(offsets, fileSize-apeTagHeaderSize-128)
	}

	for _, offset := range offsets {
		if offset < 0 {
			continue
		}
		footer := make([]byte, apeTagHeaderSize)
		if _, err := f.ReadAt(footer, offset); err != nil {
			continue
		}
		if string(footer[0:8]) != apeTagPreamble {
			continue
		}
		flags := binary.LittleEndian.Uint32(footer[20:24])
		if (flags & apeTagFlagHeader) != 0 {
			continue
		}
		tagSize := int64(binary.LittleEndian.Uint32(footer[12:16]))
		hasHeader := (flags & (1 << 31)) != 0
		totalSize := tagSize
		if hasHeader {
			totalSize += apeTagHeaderSize
		}
		trailingBytes := fileSize - (offset + apeTagHeaderSize)
		totalSize += trailingBytes
		return totalSize, nil
	}
	return 0, nil
}
