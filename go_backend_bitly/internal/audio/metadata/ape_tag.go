package metadata

import (
	"fmt"
	"os"
)

// APEv2 tag format constants.
const (
	apeTagPreamble     = "APETAGEX"
	apeTagHeaderSize   = 32
	apeTagVersion2     = 2000
	apeTagFlagHeader   = 1 << 29
	apeTagFlagReadOnly = 1 << 0
	apeItemFlagUTF8   = 0 << 1
	apeItemFlagBinary = 1 << 1
	apeItemFlagLink   = 2 << 1
)

// APETagItem represents a single key-value item in an APEv2 tag.
type APETagItem struct {
	Key   string
	Value string
	Flags uint32
}

// APETag represents a complete APEv2 tag block.
type APETag struct {
	Version  uint32
	Items    []APETagItem
	ReadOnly bool
}

// ReadAPETags reads APEv2 tags from a file.
func ReadAPETags(filePath string) (*APETag, error) {
	f, err := os.Open(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to open file: %w", err)
	}
	defer f.Close()

	fi, err := f.Stat()
	if err != nil {
		return nil, fmt.Errorf("failed to stat file: %w", err)
	}
	fileSize := fi.Size()

	if fileSize < apeTagHeaderSize {
		return nil, fmt.Errorf("file too small for APE tag")
	}

	tag, err := readAPETagAtOffset(f, fileSize, fileSize-apeTagHeaderSize)
	if err == nil {
		return tag, nil
	}

	if fileSize > apeTagHeaderSize+128 {
		tag, err = readAPETagAtOffset(f, fileSize, fileSize-apeTagHeaderSize-128)
		if err == nil {
			return tag, nil
		}
	}

	return nil, fmt.Errorf("no APEv2 tag found")
}
