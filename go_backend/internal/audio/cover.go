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

// WriteCover embeds cover art into an audio file.
// Supported formats: FLAC, MP3, M4A.
func WriteCover(filePath string, coverData []byte) error {
	ext := strings.ToLower(filepath.Ext(filePath))
	switch ext {
	case ".flac":
		return writeFLACCover(filePath, coverData)
	case ".mp3":
		return writeMP3Cover(filePath, coverData)
	case ".m4a", ".mp4":
		return writeMP4Cover(filePath, coverData)
	default:
		return fmt.Errorf("cover: unsupported format %s for writing", ext)
	}
}

func writeFLACCover(filePath string, coverData []byte) error {
	f, err := os.ReadFile(filePath)
	if err != nil {
		return err
	}

	// FLAC structure: "fLaC" + metadata blocks + audio frames
	if len(f) < 4 || string(f[:4]) != "fLaC" {
		return fmt.Errorf("cover: not a FLAC file")
	}

	// Build new PICTURE metadata block (type 6)
	// Picture type=3 (front cover), MIME type, description, data
	mimeType := detectMIME(coverData)
	mimeBytes := []byte(mimeType)
	descBytes := []byte("")

	var picBlock bytes.Buffer
	// Picture type: Front Cover = 3
	writeBE32(&picBlock, 3)
	// MIME type length + string
	writeBE32(&picBlock, uint32(len(mimeBytes)))
	picBlock.Write(mimeBytes)
	// Description length + string (empty)
	writeBE32(&picBlock, 0)
	picBlock.Write(descBytes)
	// Width, Height, Color depth, Colors used
	writeBE32(&picBlock, 0) // width (unknown)
	writeBE32(&picBlock, 0) // height
	writeBE32(&picBlock, 0) // color depth
	writeBE32(&picBlock, 0) // colors used
	// Picture data length + data
	writeBE32(&picBlock, uint32(len(coverData)))
	picBlock.Write(coverData)

	picData := picBlock.Bytes()
	blockLen := len(picData)

	// Build the metadata block header: isLast(bit7)=0, type=6, size=24bit
	var blockHeader [4]byte
	blockHeader[0] = 6                                    // type = PICTURE
	blockHeader[1] = byte(blockLen >> 16)
	blockHeader[2] = byte(blockLen >> 8)
	blockHeader[3] = byte(blockLen)

	// Insert after STREAMINFO (which is the first metadata block, 34 bytes)
	// STREAMINFO is 34 bytes (header 4 + data 30 for 16-bit FLAC)
	// Skip past "fLaC" + first metadata block
	pos := 4 // after "fLaC"
	// Read first metadata block header
	firstBlockLen := int(f[pos+1])<<16 | int(f[pos+2])<<8 | int(f[pos+3])
	firstBlockTotal := 4 + firstBlockLen // header + data
	insertPos := pos + firstBlockTotal

	// Build new file: header + new block + rest
	var out bytes.Buffer
	out.Write(f[:pos])                       // "fLaC"
	// Clear isLast on the first block and write the modified header
	firstHeader := make([]byte, 4)
	copy(firstHeader, f[pos:pos+4])
	firstHeader[0] &^= 0x80                  // clear isLast bit
	out.Write(firstHeader)                   // modified first block header
	out.Write(f[pos+4 : pos+firstBlockTotal]) // first block data
	out.Write(blockHeader[:])                 // new picture block header
	out.Write(picData)                        // new picture block data
	out.Write(f[insertPos:])                  // rest of file

	return os.WriteFile(filePath, out.Bytes(), 0644)
}

func writeMP3Cover(filePath string, coverData []byte) error {
	f, err := os.ReadFile(filePath)
	if err != nil {
		return err
	}

	if len(f) < 10 || string(f[:3]) != "ID3" {
		// No ID3 header — prepend one
		return prependID3WithCover(filePath, coverData)
	}

	tagSize := int(f[6])<<21 | int(f[7])<<14 | int(f[8])<<7 | int(f[9])
	tagEnd := 10 + tagSize

	// Check if APIC frame already exists
	apicPos := findAPICFrame(f[10:tagEnd])

	mimeType := detectMIME(coverData)
	mimeBytes := []byte(mimeType)
	picData := buildAPICFrameData(mimeBytes, coverData)

	var newTag []byte
	if apicPos >= 0 {
		// Replace existing APIC frame
		oldFrameSize := int(f[10+apicPos+4])<<24 | int(f[10+apicPos+5])<<16 |
			int(f[10+apicPos+6])<<8 | int(f[10+apicPos+7])
		frameStart := 10 + apicPos
		frameEnd := frameStart + 10 + oldFrameSize
		newTag = append(newTag, f[10:frameStart]...)
		newTag = append(newTag, picData...)
		newTag = append(newTag, f[frameEnd:tagEnd]...)
	} else {
		// Append APIC frame
		newTag = append([]byte{}, f[10:tagEnd]...)
		newTag = append(newTag, picData...)
	}

	// Update tag size
	newTagSize := len(newTag)
	f[6] = byte(newTagSize >> 21 & 0x7F)
	f[7] = byte(newTagSize >> 14 & 0x7F)
	f[8] = byte(newTagSize >> 7 & 0x7F)
	f[9] = byte(newTagSize & 0x7F)

	var out bytes.Buffer
	out.Write(f[:10])
	out.Write(newTag)
	out.Write(f[tagEnd:])

	return os.WriteFile(filePath, out.Bytes(), 0644)
}

func prependID3WithCover(filePath string, coverData []byte) error {
	mimeType := detectMIME(coverData)
	picData := buildAPICFrameData([]byte(mimeType), coverData)

	tagSize := len(picData)

	var header [10]byte
	header[0], header[1], header[2] = 'I', 'D', '3'
	header[3], header[4] = 3, 0 // version 3.0
	header[6] = byte(tagSize >> 21 & 0x7F)
	header[7] = byte(tagSize >> 14 & 0x7F)
	header[8] = byte(tagSize >> 7 & 0x7F)
	header[9] = byte(tagSize & 0x7F)

	f, err := os.ReadFile(filePath)
	if err != nil {
		return err
	}

	var out bytes.Buffer
	out.Write(header[:])
	out.Write(picData)
	out.Write(f)
	return os.WriteFile(filePath, out.Bytes(), 0644)
}

func writeMP4Cover(filePath string, coverData []byte) error {
	f, err := os.ReadFile(filePath)
	if err != nil {
		return err
	}

	// Find moov atom
	moovPos := findAtom(f, "moov")
	if moovPos < 0 {
		return fmt.Errorf("cover: no moov atom found")
	}

	// Find udta → meta → ilst
	udtaPos := findAtomIn(f[moovPos:], "udta")
	if udtaPos >= 0 {
		absUdta := moovPos + udtaPos
		metaPos := findAtomIn(f[absUdta:], "meta")
		if metaPos >= 0 {
			absMeta := absUdta + metaPos
			// Check for existing covr
			ilstPos := findAtomIn(f[absMeta:], "ilst")
			if ilstPos >= 0 {
				absIlst := absMeta + ilstPos
				covrPos := findAtomIn(f[absIlst:], "covr")
				if covrPos >= 0 {
					// Remove existing covr
					absCovr := absIlst + covrPos
					covrSize := int(f[absCovr])<<24 | int(f[absCovr+1])<<16 |
						int(f[absCovr+2])<<8 | int(f[absCovr+3])
					f = append(f[:absCovr], f[absCovr+covrSize:]...)
				}
			}
		}
	}

	// Build covr atom
	var dataAtom bytes.Buffer
	// data atom: size(4) + 'data'(4) + version(4) + data
	dataAtom.Write(encodeBE32(16 + uint32(len(coverData)))) // atom size
	dataAtom.Write([]byte("data"))
	dataAtom.Write([]byte{0, 0, 0, 0}) // version + flags
	dataAtom.Write(coverData)

	dataBytes := dataAtom.Bytes()
	var covrAtom bytes.Buffer
	covrAtom.Write(encodeBE32(8 + uint32(len(dataBytes))))
	covrAtom.Write([]byte("covr"))
	covrAtom.Write(dataBytes)

	covrBytes := covrAtom.Bytes()

	// Find or create ilst
	ilstPos := findAtomIn(f, "ilst")
	var out bytes.Buffer
	if ilstPos >= 0 {
		// Insert covr into ilst
		out.Write(f[:ilstPos+8]) // ilst header
		out.Write(covrBytes)
		// Update ilst size
		oldIlstSize := int(f[ilstPos])<<24 | int(f[ilstPos+1])<<16 | int(f[ilstPos+2])<<8 | int(f[ilstPos+3])
		newIlstSize := oldIlstSize + len(covrBytes)
		out.Write(encodeBE32(uint32(newIlstSize)))
		out.Write(f[ilstPos+8:])
	} else {
		return fmt.Errorf("cover: MP4 metadata not found, use a tagger tool first")
	}

	return os.WriteFile(filePath, out.Bytes(), 0644)
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
	return "image/jpeg" // default
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
	// Frame header: APIC + size(4) + flags(2)
	// We'll write size later
	var sizePos int
	apicFrame := func() []byte {
		var f bytes.Buffer
		f.Write([]byte("APIC"))
		sizePos = f.Len()
		f.Write([]byte{0, 0, 0, 0}) // placeholder size
		f.Write([]byte{0, 0})       // flags
		f.WriteByte(3)              // encoding: UTF-8
		f.Write(mimeBytes)
		f.WriteByte(0)              // null terminator
		f.WriteByte(3)              // picture type: front cover
		f.WriteByte(0)              // description null terminator
		f.Write(coverData)
		return f.Bytes()
	}
	data := apicFrame()
	frameSize := len(data) - 10 // excl. header
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
		// Skip to next atom
		if i+4 <= len(data) {
			size := int(data[i])<<24 | int(data[i+1])<<16 | int(data[i+2])<<8 | int(data[i+3])
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
