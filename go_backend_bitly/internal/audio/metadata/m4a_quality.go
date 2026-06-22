package metadata

import (
	"encoding/binary"
	"fmt"
	"math"
	"os"
)

// GetM4AQuality detects audio quality from an M4A file.
func GetM4AQuality(filePath string) (AudioQuality, error) {
	f, err := os.Open(filePath)
	if err != nil {
		return AudioQuality{}, fmt.Errorf("failed to open M4A file: %w", err)
	}
	defer f.Close()

	info, err := f.Stat()
	if err != nil {
		return AudioQuality{}, fmt.Errorf("failed to stat M4A file: %w", err)
	}
	fileSize := info.Size()

	moovHeader, moovFound, err := findAtomInRange(f, 0, fileSize, "moov", fileSize)
	if err != nil || !moovFound {
		return AudioQuality{}, fmt.Errorf("moov atom not found")
	}

	moovStart := moovHeader.offset
	moovEnd := moovHeader.offset + moovHeader.size
	duration := readM4ADurationSeconds(f, moovHeader, fileSize)

	sampleOffset, atomType, err := findAudioSampleEntry(f, moovStart, moovEnd, fileSize)
	if err != nil {
		return AudioQuality{}, err
	}

	buf := make([]byte, 32)
	if _, err := f.ReadAt(buf, sampleOffset); err != nil {
		return AudioQuality{}, fmt.Errorf("failed to read audio sample entry: %w", err)
	}

	sampleRate := int(buf[28])<<8 | int(buf[29])
	bitDepth := int(buf[22])<<8 | int(buf[23])

	if atomType == "alac" {
		if alacBitDepth, alacSampleRate, ok := readALACSpecificConfig(f, sampleOffset, fileSize); ok {
			if alacBitDepth > 0 {
				bitDepth = alacBitDepth
			}
			if alacSampleRate > 0 {
				sampleRate = alacSampleRate
			}
		}
	}

	if bitDepth <= 0 {
		bitDepth = 16
	}

	codec := "AAC"
	if atomType == "alac" {
		codec = "ALAC"
	}

	return AudioQuality{BitDepth: bitDepth, SampleRate: sampleRate, Duration: duration, Codec: codec}, nil
}

func readM4ADurationSeconds(f *os.File, moovHeader atomHeader, fileSize int64) int {
	childStart := moovHeader.offset + moovHeader.headerSize
	childSize := moovHeader.size - moovHeader.headerSize
	mvhdHeader, found, err := findAtomInRange(f, childStart, childSize, "mvhd", fileSize)
	if err != nil || !found {
		return 0
	}

	payloadOffset := mvhdHeader.offset + mvhdHeader.headerSize
	versionBuf := make([]byte, 1)
	if _, err := f.ReadAt(versionBuf, payloadOffset); err != nil {
		return 0
	}

	if versionBuf[0] == 1 {
		buf := make([]byte, 32)
		if _, err := f.ReadAt(buf, payloadOffset); err != nil {
			return 0
		}
		timescale := binary.BigEndian.Uint32(buf[20:24])
		duration := binary.BigEndian.Uint64(buf[24:32])
		if timescale == 0 || duration == 0 {
			return 0
		}
		return int(math.Round(float64(duration) / float64(timescale)))
	}

	buf := make([]byte, 20)
	if _, err := f.ReadAt(buf, payloadOffset); err != nil {
		return 0
	}
	timescale := binary.BigEndian.Uint32(buf[12:16])
	duration := binary.BigEndian.Uint32(buf[16:20])
	if timescale == 0 || duration == 0 {
		return 0
	}
	return int(math.Round(float64(duration) / float64(timescale)))
}
