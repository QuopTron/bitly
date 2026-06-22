package metadata

import (
	"encoding/binary"
	"math"
	"os"
	"strings"
)

// GetOggQuality detects audio quality from Ogg/Opus files.
func GetOggQuality(filePath string) (*OggQuality, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	quality := &OggQuality{}
	isOpus, preSkip := parseOggVorbisHeaders(file, filePath, quality)

	stat, err := file.Stat()
	if err != nil {
		return quality, nil
	}
	fileSize := stat.Size()

	computeOggDuration(file, fileSize, quality, isOpus, preSkip)
	return quality, nil
}

func parseOggVorbisHeaders(file *os.File, filePath string, quality *OggQuality) (bool, int) {
	packets, err := collectOggPackets(file, 5, 10)
	if err != nil && len(packets) == 0 {
		return false, 0
	}

	streamType := detectOggStreamType(packets)
	if streamType == oggStreamUnknown {
		if strings.HasSuffix(strings.ToLower(filePath), ".opus") {
			streamType = oggStreamOpus
		} else {
			streamType = oggStreamVorbis
		}
	}

	isOpus := streamType == oggStreamOpus
	var preSkip int

	if isOpus {
		for _, pkt := range packets {
			if len(pkt) >= 19 && string(pkt[0:8]) == "OpusHead" {
				quality.SampleRate = int(binary.LittleEndian.Uint32(pkt[12:16]))
				if quality.SampleRate == 0 {
					quality.SampleRate = 48000
				}
				preSkip = int(binary.LittleEndian.Uint16(pkt[10:12]))
				break
			}
		}
	} else {
		for _, pkt := range packets {
			if len(pkt) > 29 && pkt[0] == 0x01 && string(pkt[1:7]) == "vorbis" {
				quality.SampleRate = int(binary.LittleEndian.Uint32(pkt[12:16]))
				break
			}
		}
	}
	return isOpus, preSkip
}

func computeOggDuration(file *os.File, fileSize int64, quality *OggQuality, isOpus bool, preSkip int) {
	granule := readLastOggGranulePosition(file, fileSize)
	if granule > 0 {
		if isOpus {
			totalSamples := granule - int64(preSkip)
			if totalSamples > 0 {
				dur := float64(totalSamples) / 48000.0
				if dur > 0 {
					quality.Duration = int(math.Round(dur))
					quality.Bitrate = int(float64(fileSize*8) / dur)
				}
			}
		} else if quality.SampleRate > 0 {
			dur := float64(granule) / float64(quality.SampleRate)
			if dur > 0 {
				quality.Duration = int(math.Round(dur))
				quality.Bitrate = int(float64(fileSize*8) / dur)
			}
		}
	}

	if quality.Bitrate <= 0 && quality.Duration > 0 {
		quality.Bitrate = int(fileSize * 8 / int64(quality.Duration))
	}
	if quality.Duration > 24*60*60 {
		quality.Duration, quality.Bitrate = 0, 0
	}
	if quality.Bitrate > 0 && quality.Bitrate < 8000 {
		quality.Bitrate = 0
	}
}
