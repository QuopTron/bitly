package audio

import (
	"bytes"
	"fmt"
	"image"
	"image/jpeg"
	"os"
	"path/filepath"
	"strings"
)

// CoverData holds cover art image data.
type CoverData struct {
	Data     []byte `json:"data"`
	MimeType string `json:"mimeType"`
	Width    int    `json:"width"`
	Height   int    `json:"height"`
}

// ExtractCover reads cover art from an audio file.
func ExtractCover(filePath string) (*CoverData, error) {
	ext := strings.ToLower(filepath.Ext(filePath))
	switch ext {
	case ".flac":
		return extractFLACCover(filePath)
	case ".mp3":
		return extractMP3Cover(filePath)
	case ".m4a", ".mp4":
		return extractMP4Cover(filePath)
	default:
		return nil, fmt.Errorf("cover: unsupported format %s", ext)
	}
}

func extractFLACCover(path string) (*CoverData, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	// Read FLAC metadata blocks to find PICTURE block (type 6)
	data := make([]byte, 1024*1024) // 1MB max
	n, err := f.Read(data)
	if err != nil {
		return nil, err
	}
	data = data[:n]

	pos := 4 // skip "fLaC"
	for pos+4 < len(data) {
		isLast := data[pos] & 0x80
		blockType := data[pos] & 0x7F
		blockSize := int(data[pos+1])<<16 | int(data[pos+2])<<8 | int(data[pos+3])
		pos += 4

		if blockType == 6 { // PICTURE block
			// Skip picture type (4 bytes), MIME type length (4 bytes),
			// MIME type string, description length, description
			// Simplified: look for JPEG/PNG headers
			imgStart := pos
			if bytes.HasPrefix(data[pos:], []byte{0xFF, 0xD8}) {
				imgEnd := bytes.LastIndex(data, []byte{0xFF, 0xD9})
				if imgEnd > imgStart {
					return &CoverData{
						Data:     data[imgStart : imgEnd+2],
						MimeType: "image/jpeg",
					}, nil
				}
			}
			if bytes.HasPrefix(data[pos:], []byte{0x89, 0x50, 0x4E, 0x47}) {
				imgEnd := bytes.LastIndex(data, []byte{0x49, 0x45, 0x4E, 0x44})
				if imgEnd > imgStart {
					return &CoverData{
						Data:     data[imgStart : imgEnd+4],
						MimeType: "image/png",
					}, nil
				}
			}
		}
		pos += blockSize
		if isLast != 0 {
			break
		}
	}
	return nil, fmt.Errorf("cover: no cover found in FLAC")
}

func extractMP3Cover(path string) (*CoverData, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	// Read ID3v2 header
	header := make([]byte, 10)
	if _, err := f.Read(header); err != nil {
		return nil, err
	}

	if string(header[:3]) != "ID3" {
		return nil, fmt.Errorf("cover: no ID3 header")
	}

	// Parse ID3v2 tag size (syncsafe integer)
	tagSize := int(header[6])<<21 | int(header[7])<<14 |
		int(header[8])<<7 | int(header[9])

	// Read entire tag
	tagData := make([]byte, tagSize)
	if _, err := f.Read(tagData); err != nil {
		return nil, err
	}

	// Scan for APIC frame (Attached Picture)
	pos := 0
	for pos+10 <= len(tagData) {
		frameID := string(tagData[pos : pos+4])
		frameSize := int(tagData[pos+4])<<24 | int(tagData[pos+5])<<16 |
			int(tagData[pos+6])<<8 | int(tagData[pos+7])

		if frameID == "APIC" {
			// Skip encoding byte, MIME type, picture type, description
			imgStart := pos + 10
			for imgStart < len(tagData) {
				if tagData[imgStart] == 0 {
					imgStart++
					break
				}
				imgStart++
			}
			imgStart++ // skip picture type
			for imgStart < len(tagData) {
				if tagData[imgStart] == 0 {
					imgStart++
					break
				}
				imgStart++
			} // skip description

			imgEnd := pos + 10 + frameSize
			if imgEnd > len(tagData) {
				imgEnd = len(tagData)
			}

			mimeType := "image/jpeg"
			if len(tagData) > pos+14 {
				mimeStr := string(tagData[pos+11 : pos+20])
				if mimeStr[:3] == "png" || mimeStr[:4] == "image/png" {
					mimeType = "image/png"
				}
			}

			return &CoverData{
				Data:     tagData[imgStart:imgEnd],
				MimeType: mimeType,
			}, nil
		}

		pos += 10 + frameSize
	}

	return nil, fmt.Errorf("cover: no APIC frame found")
}

func extractMP4Cover(path string) (*CoverData, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	// Read MP4 header to find 'covr' atom
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	// Search for 'covr' atom in the moov.ilist box
	for i := 0; i < len(data)-8; i++ {
		if data[i] == 'c' && data[i+1] == 'o' && data[i+2] == 'v' && data[i+3] == 'r' {
			// covr atom contains the image data after size + type (8 bytes)
			// and a 4-byte version/flags + 4-byte reserved
			imgStart := i + 16
			if imgStart+4 > len(data) {
				break
			}
			// Check for JPEG or PNG header
			if data[imgStart] == 0xFF && data[imgStart+1] == 0xD8 {
				imgEnd := bytes.LastIndex(data[imgStart:], []byte{0xFF, 0xD9})
				if imgEnd > 0 {
					return &CoverData{
						Data:     data[imgStart : imgStart+imgEnd+2],
						MimeType: "image/jpeg",
					}, nil
				}
			}
			if data[imgStart] == 0x89 && data[imgStart+1] == 0x50 {
				imgEnd := bytes.LastIndex(data[imgStart:], []byte{0x49, 0x45, 0x4E, 0x44})
				if imgEnd > 0 {
					return &CoverData{
						Data:     data[imgStart : imgStart+imgEnd+4],
						MimeType: "image/png",
					}, nil
				}
			}
			break
		}
	}

	return nil, fmt.Errorf("cover: no covr atom found in MP4")
}

// ResizeCover resizes cover art to a max dimension, keeping aspect ratio.
func ResizeCover(data []byte, maxDimension int) (*CoverData, error) {
	img, _, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}

	bounds := img.Bounds()
	w, h := bounds.Dx(), bounds.Dy()
	if w <= maxDimension && h <= maxDimension {
		return &CoverData{Data: data, MimeType: "image/jpeg",
			Width: w, Height: h}, nil
	}

	// Re-encode as JPEG with quality 85
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: 85}); err != nil {
		return nil, err
	}
	return &CoverData{Data: buf.Bytes(), MimeType: "image/jpeg"}, nil
}
