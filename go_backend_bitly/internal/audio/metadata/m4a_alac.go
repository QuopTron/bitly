package metadata

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
	"os"
)

func readALACSpecificConfig(f *os.File, sampleOffset, fileSize int64) (int, int, bool) {
	if sampleOffset < 4 {
		return 0, 0, false
	}
	sampleEntryHeader, err := readAtomHeaderAt(f, sampleOffset-4, fileSize)
	if err != nil {
		return 0, 0, false
	}
	childStart := sampleOffset + 32
	childEnd := sampleEntryHeader.offset + sampleEntryHeader.size
	if childStart >= childEnd {
		return 0, 0, false
	}
	configHeader, found, err := findAtomInRange(f, childStart, childEnd-childStart, "alac", fileSize)
	if err != nil || !found {
		return 0, 0, false
	}
	payloadSize := configHeader.size - configHeader.headerSize
	if payloadSize <= 0 {
		return 0, 0, false
	}
	payload := make([]byte, payloadSize)
	if _, err := f.ReadAt(payload, configHeader.offset+configHeader.headerSize); err != nil {
		return 0, 0, false
	}
	return parseALACSpecificConfig(payload)
}

func parseALACSpecificConfig(payload []byte) (int, int, bool) {
	if len(payload) < 24 {
		return 0, 0, false
	}
	bitDepth := int(payload[5])
	sampleRate := int(binary.BigEndian.Uint32(payload[20:24]))
	if bitDepth > 0 && sampleRate > 0 {
		return bitDepth, sampleRate, true
	}
	if len(payload) >= 28 {
		bitDepth = int(payload[9])
		sampleRate = int(binary.BigEndian.Uint32(payload[24:28]))
		if bitDepth > 0 && sampleRate > 0 {
			return bitDepth, sampleRate, true
		}
	}
	return 0, 0, false
}

func findAudioSampleEntry(f *os.File, start, end, fileSize int64) (int64, string, error) {
	const chunkSize = 64 * 1024
	patternMP4A := []byte("mp4a")
	patternALAC := []byte("alac")

	var tail []byte
	readPos := start
	for readPos < end {
		toRead := end - readPos
		if toRead > chunkSize {
			toRead = chunkSize
		}
		buf := make([]byte, toRead)
		n, err := f.ReadAt(buf, readPos)
		if err != nil && err != io.EOF {
			return 0, "", fmt.Errorf("failed to read M4A atom data: %w", err)
		}
		if n == 0 {
			break
		}
		data := append(tail, buf[:n]...)
		mp4aIdx := bytes.Index(data, patternMP4A)
		alacIdx := bytes.Index(data, patternALAC)

		bestIdx := -1
		bestType := ""
		switch {
		case mp4aIdx >= 0 && alacIdx >= 0:
			if mp4aIdx <= alacIdx {
				bestIdx = mp4aIdx
				bestType = "mp4a"
			} else {
				bestIdx = alacIdx
				bestType = "alac"
			}
		case mp4aIdx >= 0:
			bestIdx = mp4aIdx
			bestType = "mp4a"
		case alacIdx >= 0:
			bestIdx = alacIdx
			bestType = "alac"
		}
		if bestIdx >= 0 {
			absolute := readPos - int64(len(tail)) + int64(bestIdx)
			return absolute, bestType, nil
		}
		if len(data) >= 3 {
			tail = append([]byte{}, data[len(data)-3:]...)
		} else {
			tail = append([]byte{}, data...)
		}
		readPos += int64(n)
	}
	return 0, "", fmt.Errorf("audio info not found in M4A file")
}
