package metadata

import (
	"fmt"
	"os"
)

// ExtractCoverFromM4A extracts cover art from an M4A file.
func ExtractCoverFromM4A(filePath string) ([]byte, error) {
	f, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	fi, err := f.Stat()
	if err != nil {
		return nil, err
	}
	fileSize := fi.Size()

	ilst, err := findM4AIlstAtom(f, fileSize)
	if err != nil {
		return nil, err
	}

	bodyStart := ilst.offset + ilst.headerSize
	bodySize := ilst.size - ilst.headerSize

	covr, found, err := findAtomInRange(f, bodyStart, bodySize, "covr", fileSize)
	if err != nil || !found {
		return nil, fmt.Errorf("cover atom not found")
	}

	dataStart := covr.offset + covr.headerSize
	dataSize := covr.size - covr.headerSize
	dataAtom, found, err := findAtomInRange(f, dataStart, dataSize, "data", fileSize)
	if err != nil || !found {
		return nil, fmt.Errorf("data atom not found in cover")
	}

	imgStart := dataAtom.offset + dataAtom.headerSize + 8
	imgLen := dataAtom.size - dataAtom.headerSize - 8
	if imgLen <= 0 {
		return nil, fmt.Errorf("empty cover data")
	}

	buf := make([]byte, imgLen)
	if _, err := f.ReadAt(buf, imgStart); err != nil {
		return nil, err
	}
	return buf, nil
}
