package metadata

import (
	"encoding/binary"
	"fmt"
	"os"
	"strings"
)

func readM4ADataAtomPayload(f *os.File, dataAtom atomHeader) ([]byte, error) {
	payloadStart := dataAtom.offset + dataAtom.headerSize + 8
	payloadLen := dataAtom.size - dataAtom.headerSize - 8
	if payloadLen <= 0 {
		return nil, fmt.Errorf("empty data atom in %s", dataAtom.typ)
	}
	buf := make([]byte, payloadLen)
	if _, err := f.ReadAt(buf, payloadStart); err != nil {
		return nil, err
	}
	return buf, nil
}

func readM4ADataPayload(f *os.File, parent atomHeader, fileSize int64) ([]byte, error) {
	dataStart := parent.offset + parent.headerSize
	dataSize := parent.size - parent.headerSize
	dataAtom, found, err := findAtomInRange(f, dataStart, dataSize, "data", fileSize)
	if err != nil || !found {
		return nil, fmt.Errorf("data atom not found in %s", parent.typ)
	}
	return readM4ADataAtomPayload(f, dataAtom)
}

func readM4ATextValue(f *os.File, parent atomHeader, fileSize int64) (string, error) {
	payload, err := readM4ADataPayload(f, parent, fileSize)
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(strings.TrimRight(string(payload), "\x00")), nil
}

func readM4AIndexPair(f *os.File, parent atomHeader, fileSize int64) (int, int, error) {
	payload, err := readM4ADataPayload(f, parent, fileSize)
	if err != nil {
		return 0, 0, err
	}
	if len(payload) < 6 {
		return 0, 0, fmt.Errorf("index payload too short in %s", parent.typ)
	}
	return int(binary.BigEndian.Uint16(payload[2:4])), int(binary.BigEndian.Uint16(payload[4:6])), nil
}

func readM4AFreeformValue(f *os.File, parent atomHeader, fileSize int64) (string, string, error) {
	start := parent.offset + parent.headerSize
	end := parent.offset + parent.size

	var nameValue string
	var dataValue string
	for pos := start; pos+8 <= end; {
		header, err := readAtomHeaderAt(f, pos, fileSize)
		if err != nil {
			return "", "", err
		}
		if header.size == 0 {
			header.size = end - pos
		}
		if header.size < header.headerSize {
			return "", "", fmt.Errorf("invalid atom size for %s", header.typ)
		}

		switch header.typ {
		case "mean":
		case "name":
			payloadStart := header.offset + header.headerSize + 4
			payloadLen := header.size - header.headerSize - 4
			if payloadLen > 0 {
				buf := make([]byte, payloadLen)
				if _, readErr := f.ReadAt(buf, payloadStart); readErr == nil {
					nameValue = strings.TrimSpace(strings.TrimRight(string(buf), "\x00"))
				}
			}
		case "data":
			payload, payloadErr := readM4ADataAtomPayload(f, header)
			if payloadErr == nil {
				dataValue = strings.TrimSpace(strings.TrimRight(string(payload), "\x00"))
			}
		}
		pos += header.size
	}
	if nameValue == "" || dataValue == "" {
		return "", "", fmt.Errorf("freeform M4A tag incomplete")
	}
	return nameValue, dataValue, nil
}
