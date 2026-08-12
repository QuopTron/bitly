package audio

import (
	"bytes"
	"image"
	"image/jpeg"
)

// ResizeCover resizes cover art to a max dimension, keeping aspect ratio.
func ResizeCover(data []byte, maxDimension int) (*CoverData, error) {
	img, _, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}

	bounds := img.Bounds()
	w, h := bounds.Dx(), bounds.Dy()
	if w <= maxDimension && h <= maxDimension {
		return &CoverData{Data: data, MimeType: "image/jpeg", Width: w, Height: h}, nil
	}

	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: 85}); err != nil {
		return nil, err
	}
	return &CoverData{Data: buf.Bytes(), MimeType: "image/jpeg"}, nil
}

// --- Binary helpers ---

func writeBE32(buf *bytes.Buffer, v uint32) {
	buf.Write([]byte{byte(v >> 24), byte(v >> 16), byte(v >> 8), byte(v)})
}

func encodeBE32(v uint32) []byte {
	return []byte{byte(v >> 24), byte(v >> 16), byte(v >> 8), byte(v)}
}

func detectMIME(data []byte) string {
	if len(data) < 4 {
		return "image/jpeg"
	}
	if data[0] == 0xFF && data[1] == 0xD8 {
		return "image/jpeg"
	}
	if data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 {
		return "image/png"
	}
	return "image/jpeg"
}

func findAPICFrame(tagData []byte) int {
	pos := 0
	for pos+10 <= len(tagData) {
		if string(tagData[pos:pos+4]) == "APIC" {
			return pos
		}
		frameSize := int(tagData[pos+4])<<24 | int(tagData[pos+5])<<16 |
			int(tagData[pos+6])<<8 | int(tagData[pos+7])
		pos += 10 + frameSize
	}
	return -1
}

func buildAPICFrameData(mimeBytes, coverData []byte) []byte {
	var sizePos int
	var f bytes.Buffer
	f.Write([]byte("APIC"))
	sizePos = f.Len()
	f.Write([]byte{0, 0, 0, 0}) // placeholder size
	f.Write([]byte{0, 0})       // flags
	f.WriteByte(3)              // encoding: UTF-8
	f.Write(mimeBytes)
	f.WriteByte(0)   // null terminator
	f.WriteByte(3)   // picture type: front cover
	f.WriteByte(0)   // description null terminator
	f.Write(coverData)
	data := f.Bytes()
	frameSize := len(data) - 10
	data[sizePos] = byte(frameSize >> 24)
	data[sizePos+1] = byte(frameSize >> 16)
	data[sizePos+2] = byte(frameSize >> 8)
	data[sizePos+3] = byte(frameSize)
	return data
}

func findAtom(data []byte, atomName string) int {
	for i := 0; i <= len(data)-8; i++ {
		if string(data[i+4:i+8]) == atomName {
			return i
		}
		if i+4 <= len(data) {
			size := int(data[i])<<24 | int(data[i+1])<<16 |
				int(data[i+2])<<8 | int(data[i+3])
			if size > 0 {
				i += size - 1
			} else {
				break
			}
		}
	}
	return -1
}

func findAtomIn(data []byte, atomName string) int {
	for i := 0; i <= len(data)-8; i++ {
		if string(data[i+4:i+8]) == atomName {
			return i
		}
	}
	return -1
}
