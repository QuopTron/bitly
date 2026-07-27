package audio

import (
	"fmt"
	"os"
)

func readFLAC(path string, meta *Metadata) (*Metadata, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	// Read FLAC metadata markers
	header := make([]byte, 42)
	if _, err := f.Read(header); err != nil {
		return nil, err
	}

	// FLAC starts with "fLaC"
	if string(header[:4]) != "fLaC" {
		return nil, fmt.Errorf("audio: not a FLAC file")
	}

	// Min block size, max block size, min frame size, max frame size, sample rate,
	// channels, bits per sample, total samples
	meta.SampleRate = int(readBits(header[18:21], 20))
	meta.BitDepth = int(readBits(header[21:22], 5) + 1)

	// Total samples (36 bits at offset 22)
	totalSamples := readBits(header[22:27], 36)
	if totalSamples > 0 && meta.SampleRate > 0 {
		meta.DurationMs = int(totalSamples * 1000 / int64(meta.SampleRate))
	}

	meta.Bitrate = int(int64(meta.FileSize) * 8 / (int64(meta.DurationMs) / 1000) / 1000)
	return meta, nil
}

func readMP3(path string, meta *Metadata) (*Metadata, error) {
	// MP3 ID3v2 header is at the start
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	header := make([]byte, 10)
	if _, err := f.Read(header); err != nil {
		return nil, err
	}

	// Check ID3v2 header
	if string(header[:3]) == "ID3" {
		// Tag size is synchsafe integer in bytes 6-9
		tagSize := int(header[6])<<21 | int(header[7])<<14 |
			int(header[8])<<7 | int(header[9])
		// Skip to audio data for bitrate estimate
		// For now, approximate duration from file size at 192kbps
		estBitrate := 192
		meta.Bitrate = estBitrate
		meta.DurationMs = int((meta.FileSize-int64(tagSize)) * 8 / int64(estBitrate) / 1000 * 1000)
	}

	meta.SampleRate = 44100
	meta.BitDepth = 16
	return meta, nil
}

func readMP4(path string, meta *Metadata) (*Metadata, error) {
	// MP4/M4A: parse moov → mvhd atom for duration + sample rate
	// Simplified: estimate from file size at 256kbps
	estBitrate := 256
	meta.Bitrate = estBitrate
	overhead := int64(4096) // header overhead
	audioBytes := meta.FileSize - overhead
	if audioBytes > 0 && estBitrate > 0 {
		meta.DurationMs = int(audioBytes * 8 / int64(estBitrate))
	}
	meta.SampleRate = 44100
	meta.BitDepth = 16
	return meta, nil
}

func readOGG(path string, meta *Metadata) (*Metadata, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	header := make([]byte, 28)
	if _, err := f.Read(header); err != nil {
		return nil, err
	}

	if string(header[:4]) != "OggS" {
		return nil, fmt.Errorf("audio: not an OGG file")
	}

	// Vorbis header: sample rate at bytes 12-15
	meta.SampleRate = int(header[12]) | int(header[13])<<8 |
		int(header[14])<<16 | int(header[15])<<24
	meta.BitDepth = 16

	// Estimate bitrate
	meta.Bitrate = 160
	if meta.SampleRate > 0 {
		samples := meta.FileSize / 2 // ~2 bytes per sample approximated
		meta.DurationMs = int(samples * 1000 / int64(meta.SampleRate))
	}
	return meta, nil
}

func readWAV(path string, meta *Metadata) (*Metadata, error) {
	meta.SampleRate = 44100
	meta.BitDepth = 16
	meta.Bitrate = 1411 // CD quality
	if meta.FileSize > 44 { // WAV header is 44 bytes
		audioBytes := meta.FileSize - 44
		meta.DurationMs = int(audioBytes * 8 / int64(meta.SampleRate) / int64(meta.BitDepth/8) / 2 * 1000)
	}
	return meta, nil
}

func readAIFF(path string, meta *Metadata) (*Metadata, error) {
	meta.SampleRate = 44100
	meta.BitDepth = 16
	meta.Bitrate = 1411
	return meta, nil
}

// readBits reads n bits from a byte slice (big-endian).
func readBits(data []byte, n int) int64 {
	var result int64
	for i := 0; i < len(data) && n > 0; {
		bits := 8
		if n < 8 {
			bits = n
		}
		result = (result << bits) | int64(data[i]>>(8-bits))
		n -= bits
		i++
	}
	return result
}
