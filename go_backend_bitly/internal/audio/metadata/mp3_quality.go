package metadata

import (
	"io"
	"os"
)

// GetMP3Quality detects audio quality from an MP3 file.
func GetMP3Quality(filePath string) (*MP3Quality, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	quality := &MP3Quality{}
	stat, err := file.Stat()
	if err != nil {
		return nil, err
	}
	fileSize := stat.Size()

	header := make([]byte, 10)
	if _, err := io.ReadFull(file, header); err != nil {
		return quality, nil
	}
	var audioStart int64 = 0
	if string(header[0:3]) == "ID3" {
		tagSize := int64(header[6])>>21 | int64(header[7])>>14 | int64(header[8])>>7 | int64(header[9])
		audioStart = 10 + tagSize
	}

	frameStart, frameHeader := scanMP3FrameSync(file, audioStart)
	if frameStart < 0 {
		return quality, nil
	}

	version := (frameHeader[1] >> 3) & 0x03
	layer := (frameHeader[1] >> 1) & 0x03
	bitrateIdx := (frameHeader[2] >> 4) & 0x0F
	sampleRateIdx := (frameHeader[2] >> 2) & 0x03
	channelMode := (frameHeader[3] >> 6) & 0x03

	xingOffset := parseMP3QualityHeader(version, layer, bitrateIdx, sampleRateIdx, channelMode, quality)

	vbrFrames, vbrBytes, isVBR := detectMP3VBR(file, frameStart, xingOffset)

	samplesPerFrame := 1152
	if version == 0 || version == 2 {
		samplesPerFrame = 576
	}

	computeMP3Duration(quality, isVBR, vbrFrames, vbrBytes, fileSize, audioStart, samplesPerFrame)
	return quality, nil
}

func scanMP3FrameSync(file *os.File, audioStart int64) (int64, []byte) {
	file.Seek(audioStart, io.SeekStart)
	frameHeader := make([]byte, 4)
	var frameStart int64 = -1
	for i := 0; i < 10000; i++ {
		if _, err := io.ReadFull(file, frameHeader); err != nil {
			break
		}
		if frameHeader[0] == 0xFF && (frameHeader[1]&0xE0) == 0xE0 {
			pos, _ := file.Seek(0, io.SeekCurrent)
			frameStart = pos - 4
			break
		}
		file.Seek(-3, io.SeekCurrent)
	}
	return frameStart, frameHeader
}

func parseMP3QualityHeader(version byte, layer byte, bitrateIdx byte, sampleRateIdx byte, channelMode byte, quality *MP3Quality) int {
	_ = layer
	sampleRates := [][]int{
		{11025, 12000, 8000},
		{0, 0, 0},
		{22050, 24000, 16000},
		{44100, 48000, 32000},
	}
	if version < 4 && sampleRateIdx < 3 {
		quality.SampleRate = sampleRates[version][sampleRateIdx]
	}

	if version == 3 && layer == 1 {
		bitrates := []int{0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0}
		if bitrateIdx < 16 {
			quality.Bitrate = bitrates[bitrateIdx] * 1000
		}
	}
	if (version == 0 || version == 2) && layer == 1 {
		bitrates := []int{0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0}
		if bitrateIdx < 16 {
			quality.Bitrate = bitrates[bitrateIdx] * 1000
		}
	}

	var xingOffset int
	if version == 3 {
		if channelMode == 3 {
			xingOffset = 17
		} else {
			xingOffset = 32
		}
	} else {
		if channelMode == 3 {
			xingOffset = 9
		} else {
			xingOffset = 17
		}
	}
	return xingOffset
}
