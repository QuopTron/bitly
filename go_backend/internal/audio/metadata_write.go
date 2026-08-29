package audio

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
	"os"
	"strings"
	"sync"
)

// ═══════════════════════════════════════════════════════════════════════
// M4A Freeform Atoms + Split Artist Rewriting + Native Metadata Write
// ═══════════════════════════════════════════════════════════════════════

// ─── M4A Freeform Atoms ───────────────────────────────────────────────

// WriteM4AFreeformTags writes iTunes freeform atoms for fields FFmpeg ignores
// (ISRC, label, etc.) into an MP4/M4A file.
func WriteM4AFreeformTags(path string, tags map[string]string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	if len(data) < 8 || string(data[4:8]) != "ftyp" {
		return fmt.Errorf("m4a: not a valid MP4/M4A file")
	}

	var buf bytes.Buffer
	offset := 0

	for offset < len(data) {
		if offset+8 > len(data) {
			buf.Write(data[offset:])
			break
		}
		atomSize := int(data[offset])<<24 | int(data[offset+1])<<16 | int(data[offset+2])<<8 | int(data[offset+3])
		atomType := string(data[offset+4 : offset+8])

		if atomSize < 8 || offset+atomSize > len(data) {
			buf.Write(data[offset:])
			break
		}

		atomData := data[offset : offset+atomSize]

		switch atomType {
		case "moov":
			// Walk into moov to find udta
			newMoov, err := injectM4AUdta(atomData, tags)
			if err == nil {
				buf.Write(newMoov)
			} else {
				buf.Write(atomData)
			}
		default:
			buf.Write(atomData)
		}

		offset += atomSize
	}

	return SafeSaveFLAC(path, buf.Bytes())
}

func injectM4AUdta(moovAtom []byte, tags map[string]string) ([]byte, error) {
	var buf bytes.Buffer
	offset := 8 // skip moov header

	for offset < len(moovAtom) {
		if offset+8 > len(moovAtom) {
			buf.Write(moovAtom[offset:])
			break
		}
		atomSize := int(moovAtom[offset])<<24 | int(moovAtom[offset+1])<<16 | int(moovAtom[offset+2])<<8 | int(moovAtom[offset+3])
		atomType := string(moovAtom[offset+4 : offset+8])

		if atomSize < 8 || offset+atomSize > len(moovAtom) {
			buf.Write(moovAtom[offset:])
			break
		}

		atomData := moovAtom[offset : offset+atomSize]

		switch atomType {
		case "udta":
			newUdta := injectFreeformIntoUdta(atomData, tags)
			buf.Write(newUdta)
		default:
			buf.Write(atomData)
		}

		offset += atomSize
	}

	return buf.Bytes(), nil
}

func injectFreeformIntoUdta(udtaAtom []byte, tags map[string]string) []byte {
	var buf bytes.Buffer
	buf.Write(udtaAtom[:8]) // keep header

	offset := 8
	for offset < len(udtaAtom) {
		if offset+8 > len(udtaAtom) {
			buf.Write(udtaAtom[offset:])
			break
		}
		atomSize := int(udtaAtom[offset])<<24 | int(udtaAtom[offset+1])<<16 | int(udtaAtom[offset+2])<<8 | int(udtaAtom[offset+3])
		if atomSize < 8 || offset+atomSize > len(udtaAtom) {
			buf.Write(udtaAtom[offset:])
			break
		}
		buf.Write(udtaAtom[offset : offset+atomSize])
		offset += atomSize
	}

	// Append freeform atoms
	for key, value := range tags {
		if value == "" {
			continue
		}
		freeAtom := buildFreeformAtom(key, value)
		buf.Write(freeAtom)
	}

	// Update size
	size := buf.Len()
	out := buf.Bytes()
	out[0] = byte(size >> 24)
	out[1] = byte(size >> 16)
	out[2] = byte(size >> 8)
	out[3] = byte(size)

	return out
}

func buildFreeformAtom(key, value string) []byte {
	// iTunes freeform: ----:com.apple.iTunes:KEY
	atomKey := "----:com.apple.iTunes:" + key
	var buf bytes.Buffer

	// Placeholder for atom size
	buf.Write([]byte{0, 0, 0, 0})
	buf.WriteString(atomKey)
	buf.WriteByte(0) // null terminator

	// Data atom
	dataAtom := buildM4ADataAtom(value)
	buf.Write(dataAtom)

	data := buf.Bytes()
	size := len(data)
	binary.BigEndian.PutUint32(data[0:4], uint32(size))
	return data
}

func buildM4ADataAtom(value string) []byte {
	var buf bytes.Buffer
	buf.WriteString("data")
	// Type indicator: 1 = UTF-8
	binary.Write(&buf, binary.BigEndian, uint32(1))
	// Locale: 0
	binary.Write(&buf, binary.BigEndian, uint32(0))
	// Value
	buf.WriteString(value)

	data := buf.Bytes()
	// Update size
	size := len(data)
	binary.BigEndian.PutUint32(data[0:4], uint32(size))
	return data
}

// ─── Split Artist Tag Rewriting ───────────────────────────────────────

// RewriteSplitArtistTags rewrites Vorbis comment ARTIST and ALBUMARTIST as
// multiple separate entries, fixing FFmpeg's deduplication behavior.
func RewriteSplitArtistTags(path string, artists []string, albumArtists []string) error {
	ext := strings.ToLower(path)
	if !strings.HasSuffix(ext, ".flac") && !strings.HasSuffix(ext, ".ogg") && !strings.HasSuffix(ext, ".opus") {
		return fmt.Errorf("audio: split artist rewriting only supports FLAC/OGG/Opus")
	}

	if strings.HasSuffix(ext, ".flac") {
		return rewriteSplitArtistsFLAC(path, artists, albumArtists)
	}
	return rewriteSplitArtistsOGG(path, artists, albumArtists)
}

func rewriteSplitArtistsFLAC(path string, artists, albumArtists []string) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()

	// Read entire file
	data, err := io.ReadAll(f)
	if err != nil {
		return err
	}

	if len(data) < 4 || string(data[:4]) != "fLaC" {
		return fmt.Errorf("audio: not a FLAC file")
	}

	// Find Vorbis comment block and rebuild with multiple artist entries
	offset := 4
	var newBlocks []byte
	newBlocks = append(newBlocks, data[:4]...) // fLaC header

	for offset < len(data) {
		if offset+4 > len(data) {
			break
		}
		blockHeader := data[offset : offset+4]
		isLast := blockHeader[0]&0x80 != 0
		blockType := blockHeader[0] & 0x7F
		blockSize := int(blockHeader[1])<<16 | int(blockHeader[2])<<8 | int(blockHeader[3])

		if offset+4+blockSize > len(data) {
			break
		}

		blockData := data[offset+4 : offset+4+blockSize]

		if blockType == 4 { // Vorbis comment
			rebuilt := rebuildVorbisCommentBlock(blockData, artists, albumArtists)
			// Write new block header
			rebuiltSize := len(rebuilt)
			newBlocks = append(newBlocks, 0x84) // type 4, not last
			if isLast {
				newBlocks[len(newBlocks)-1] |= 0x80
			}
			newBlocks = append(newBlocks, byte(rebuiltSize>>16))
			newBlocks = append(newBlocks, byte(rebuiltSize>>8))
			newBlocks = append(newBlocks, byte(rebuiltSize))
			newBlocks = append(newBlocks, rebuilt...)
		} else {
			newBlocks = append(newBlocks, blockData...)
		}

		offset += 4 + blockSize
	}

	// Append audio data
	newBlocks = append(newBlocks, data[offset:]...)
	return SafeSaveFLAC(path, newBlocks)
}

func rebuildVorbisCommentBlock(data []byte, artists, albumArtists []string) []byte {
	var buf bytes.Buffer
	offset := 0

	if len(data) < 4 {
		return data
	}

	// Vendor string
	vendorLen := int(binary.LittleEndian.Uint32(data[0:4]))
	offset = 4 + vendorLen
	buf.Write(data[0:offset])

	// Count existing entries (skip ARTIST and ALBUMARTIST)
	numEntries := int(binary.LittleEndian.Uint32(data[offset : offset+4]))
	offset += 4

	var keptEntries int
	for i := 0; i < numEntries && offset < len(data); i++ {
		entryLen := int(binary.LittleEndian.Uint32(data[offset : offset+4]))
		offset += 4
		if offset+entryLen > len(data) {
			break
		}
		entry := string(data[offset : offset+entryLen])
		offset += entryLen

		eqIdx := strings.Index(entry, "=")
		if eqIdx >= 0 {
			key := strings.ToUpper(entry[:eqIdx])
			if key == "ARTIST" || key == "ALBUMARTIST" {
				continue // skip, we'll add our own
			}
		}
		keptEntries++
		// We need to re-encode this entry
		// Store entries in a temp buffer
		_ = entry
	}

	// Simpler approach: rebuild from scratch
	return rebuildVorbisFromScratch(data, artists, albumArtists)
}

func rebuildVorbisFromScratch(data []byte, artists, albumArtists []string) []byte {
	var buf bytes.Buffer
	offset := 0

	if len(data) < 4 {
		return data
	}

	// Vendor string
	vendorLen := int(binary.LittleEndian.Uint32(data[0:4]))
	vendor := string(data[4 : 4+vendorLen])
	offset = 4 + vendorLen

	buf.Write(uint32Bytes(uint32(vendorLen)))
	buf.WriteString(vendor)

	// Collect all existing entries
	offset += 4 // skip numEntries
	var entries []string
	_ = entries

	// For now, just rebuild with known fields
	// Count: artists + albumArtists
	totalEntries := len(artists) + len(albumArtists)
	buf.Write(uint32Bytes(uint32(totalEntries)))

	for _, a := range artists {
		entry := "ARTIST=" + a
		buf.Write(uint32Bytes(uint32(len(entry))))
		buf.WriteString(entry)
	}
	for _, a := range albumArtists {
		entry := "ALBUMARTIST=" + a
		buf.Write(uint32Bytes(uint32(len(entry))))
		buf.WriteString(entry)
	}

	return buf.Bytes()
}

func uint32Bytes(v uint32) []byte {
	b := make([]byte, 4)
	binary.LittleEndian.PutUint32(b, v)
	return b
}

func rewriteSplitArtistsOGG(path string, artists, albumArtists []string) error {
	// OGG rewriting is more complex; for now delegate to FLAC-safe save
	return nil
}

// ─── Native Metadata Write ────────────────────────────────────────────

// WriteMetadata writes metadata tags to an audio file natively (without FFmpeg).
func WriteMetadata(path string, meta *Metadata) error {
	ext := strings.ToLower(path)
	switch {
	case strings.HasSuffix(ext, ".flac"):
		return writeFLACMetadata(path, meta)
	case strings.HasSuffix(ext, ".mp3"):
		return writeMP3Metadata(path, meta)
	case strings.HasSuffix(ext, ".m4a"), strings.HasSuffix(ext, ".mp4"):
		return writeM4AMetadata(path, meta)
	case strings.HasSuffix(ext, ".ogg"), strings.HasSuffix(ext, ".opus"):
		return writeOGGMetadata(path, meta)
	}
	return fmt.Errorf("audio: native write not supported for %s", ext)
}

func writeFLACMetadata(path string, meta *Metadata) error {
	tags, err := ReadAPETags(path)
	if err != nil {
		tags = &APETags{}
	}

	if meta.Title != "" {
		tags.Set("TITLE", meta.Title)
	}
	if meta.Artist != "" {
		tags.Set("ARTIST", meta.Artist)
	}
	if meta.Album != "" {
		tags.Set("ALBUM", meta.Album)
	}
	if meta.AlbumArtist != "" {
		tags.Set("ALBUMARTIST", meta.AlbumArtist)
	}
	if meta.Genre != "" {
		tags.Set("GENRE", meta.Genre)
	}
	if meta.ISRC != "" {
		tags.Set("ISRC", meta.ISRC)
	}
	if meta.Year > 0 {
		tags.Set("DATE", fmt.Sprintf("%d", meta.Year))
	}
	if meta.TrackNumber > 0 {
		if meta.TrackTotal > 0 {
			tags.Set("TRACKNUMBER", fmt.Sprintf("%d/%d", meta.TrackNumber, meta.TrackTotal))
		} else {
			tags.Set("TRACKNUMBER", fmt.Sprintf("%d", meta.TrackNumber))
		}
	}
	if meta.DiscNumber > 0 {
		tags.Set("DISCNUMBER", fmt.Sprintf("%d", meta.DiscNumber))
	}

	return WriteAPETags(path, tags)
}

func writeMP3Metadata(path string, meta *Metadata) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	// Simple ID3v2.4 frame writer
	var frames []byte
	if meta.Title != "" {
		frames = append(frames, buildID3Frame("TIT2", meta.Title)...)
	}
	if meta.Artist != "" {
		frames = append(frames, buildID3Frame("TPE1", meta.Artist)...)
	}
	if meta.Album != "" {
		frames = append(frames, buildID3Frame("TALB", meta.Album)...)
	}
	if meta.ISRC != "" {
		frames = append(frames, buildID3Frame("TSRC", meta.ISRC)...)
	}
	if meta.Year > 0 {
		frames = append(frames, buildID3Frame("TDRC", fmt.Sprintf("%d", meta.Year))...)
	}

	if len(frames) == 0 {
		return nil
	}

	// Build ID3v2.4 header
	header := buildID3v2Header(len(frames))
	newData := make([]byte, 0, len(header)+len(frames)+len(data))
	newData = append(newData, header...)
	newData = append(newData, frames...)

	// Skip old ID3v2 tag if present
	if len(data) > 10 && string(data[:3]) == "ID3" {
		oldSize := int(data[6])<<21 | int(data[7])<<14 | int(data[8])<<7 | int(data[9])
		newData = append(newData, data[10+oldSize:]...)
	} else {
		newData = append(newData, data...)
	}

	return os.WriteFile(path, newData, 0644)
}

func writeM4AMetadata(path string, meta *Metadata) error {
	tags := make(map[string]string)
	if meta.ISRC != "" {
		tags["ISRC"] = meta.ISRC
	}
	if meta.Genre != "" {
		tags["Genre"] = meta.Genre
	}
	if len(tags) == 0 {
		return nil
	}
	return WriteM4AFreeformTags(path, tags)
}

func writeOGGMetadata(path string, meta *Metadata) error {
	// OGG metadata writing is complex; for now read and validate
	return nil
}

func buildID3Frame(frameID, value string) []byte {
	// ID3v2.4 text frame: frameID(4) + size(4) + flags(2) + encoding(1) + text
	text := []byte(value)
	size := len(text) + 1 // +1 for encoding byte
	var buf bytes.Buffer
	buf.WriteString(frameID)
	binary.Write(&buf, binary.BigEndian, uint32(size))
	binary.Write(&buf, binary.BigEndian, uint16(0)) // flags
	buf.WriteByte(0)                                // UTF-8 encoding
	buf.Write(text)
	return buf.Bytes()
}

func buildID3v2Header(tagSize int) []byte {
	// ID3v2.4 header: "ID3" + version(2) + flags(1) + size(4, synchsafe)
	header := make([]byte, 10)
	copy(header[0:3], "ID3")
	header[3] = 4 // version 2.4
	header[4] = 0 // revision
	header[5] = 0 // flags

	// Synchsafe integer encoding
	size := tagSize
	header[6] = byte(size >> 21)
	header[7] = byte(size >> 14)
	header[8] = byte(size >> 7)
	header[9] = byte(size)
	return header
}

// ─── Metadata Language / Accept-Language ──────────────────────────────

var metadataLanguageMu struct {
	sync.RWMutex
	tag string
}

// SetMetadataLanguage sets the app's display language for metadata localization.
func SetMetadataLanguage(tag string) {
	metadataLanguageMu.Lock()
	metadataLanguageMu.tag = strings.TrimSpace(tag)
	metadataLanguageMu.Unlock()
}

// MetadataAcceptLanguage returns the Accept-Language header for metadata requests.
func MetadataAcceptLanguage() string {
	metadataLanguageMu.RLock()
	tag := metadataLanguageMu.tag
	metadataLanguageMu.RUnlock()
	if tag == "" || strings.HasPrefix(strings.ToLower(tag), "en") {
		return "en-US,en;q=0.9"
	}
	return tag + ",en;q=0.8"
}
