package metadata

import (
	"fmt"
	"os"
)

// GetFlacQuality reads audio quality from a FLAC file.
func GetFlacQuality(filePath string) (AudioQuality, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return AudioQuality{}, fmt.Errorf("failed to open file: %w", err)
	}
	defer file.Close()

	marker := make([]byte, 4)
	if _, err := file.Read(marker); err != nil {
		return AudioQuality{}, fmt.Errorf("failed to read marker: %w", err)
	}
	if string(marker) != "fLaC" {
		return AudioQuality{}, fmt.Errorf("not a FLAC file")
	}

	header := make([]byte, 4)
	if _, err := file.Read(header); err != nil {
		return AudioQuality{}, fmt.Errorf("failed to read header: %w", err)
	}
	blockType := header[0] & 0x7F
	if blockType != 0 {
		return AudioQuality{}, fmt.Errorf("first block is not STREAMINFO")
	}

	streamInfo := make([]byte, 34)
	if _, err := file.Read(streamInfo); err != nil {
		return AudioQuality{}, fmt.Errorf("failed to read STREAMINFO: %w", err)
	}

	sampleRate := (int(streamInfo[10])<<12 | int(streamInfo[11])<<4 | int(streamInfo[12])>>4)
	bitsPerSample := ((int(streamInfo[12])&0x01)<<4 | int(streamInfo[13])>>4) + 1
	totalSamples := int64(streamInfo[13]&0x0F)<<32 |
		int64(streamInfo[14])<<24 |
		int64(streamInfo[15])<<16 |
		int64(streamInfo[16])<<8 |
		int64(streamInfo[17])

	duration := 0
	if sampleRate > 0 && totalSamples > 0 {
		duration = int(totalSamples / int64(sampleRate))
	}

	return AudioQuality{
		BitDepth:     bitsPerSample,
		SampleRate:   sampleRate,
		TotalSamples: totalSamples,
		Duration:     duration,
		Codec:        "FLAC",
	}, nil
}
