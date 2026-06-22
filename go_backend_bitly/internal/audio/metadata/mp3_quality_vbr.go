package metadata

import (
	"encoding/binary"
	"io"
	"os"
)

func detectMP3VBR(file *os.File, frameStart int64, xingOffset int) (int, int64, bool) {
	xingBuf := make([]byte, 200)
	file.Seek(frameStart+4, io.SeekStart)
	n, _ := io.ReadFull(file, xingBuf)
	xingBuf = xingBuf[:n]

	vbrFrames := 0
	vbrBytes := int64(0)
	isVBR := false

	if xingOffset+8 <= n {
		tag := string(xingBuf[xingOffset : xingOffset+4])
		if tag == "Xing" || tag == "Info" {
			flags := binary.BigEndian.Uint32(xingBuf[xingOffset+4 : xingOffset+8])
			off := xingOffset + 8
			if flags&0x01 != 0 && off+4 <= n {
				vbrFrames = int(binary.BigEndian.Uint32(xingBuf[off : off+4]))
				off += 4
			}
			if flags&0x02 != 0 && off+4 <= n {
				vbrBytes = int64(binary.BigEndian.Uint32(xingBuf[off : off+4]))
			}
			if vbrFrames > 0 {
				isVBR = true
			}
		}
	}

	if !isVBR && 36+26 <= n {
		if string(xingBuf[32:36]) == "VBRI" {
			vbrBytes = int64(binary.BigEndian.Uint32(xingBuf[36+6 : 36+10]))
			vbrFrames = int(binary.BigEndian.Uint32(xingBuf[36+10 : 36+14]))
			if vbrFrames > 0 {
				isVBR = true
			}
		}
	}
	return vbrFrames, vbrBytes, isVBR
}

func computeMP3Duration(quality *MP3Quality, isVBR bool, vbrFrames int, vbrBytes int64, fileSize int64, audioStart int64, samplesPerFrame int) {
	if isVBR && vbrFrames > 0 && quality.SampleRate > 0 {
		totalSamples := int64(vbrFrames) * int64(samplesPerFrame)
		quality.Duration = int(totalSamples / int64(quality.SampleRate))
		if vbrBytes > 0 && quality.Duration > 0 {
			quality.Bitrate = int(vbrBytes * 8 / int64(quality.Duration))
		} else if quality.Duration > 0 {
			audioSize := fileSize - audioStart
			quality.Bitrate = int(audioSize * 8 / int64(quality.Duration))
		}
	} else if quality.Bitrate > 0 {
		audioSize := fileSize - audioStart - 128
		if audioSize > 0 {
			quality.Duration = int(audioSize * 8 / int64(quality.Bitrate))
		}
	}
}
