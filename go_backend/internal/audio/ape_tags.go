package audio

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
	"os"
	"strings"
)

// ═══════════════════════════════════════════════════════════════════════
// APE Tag Support — native APEv2 read/write for lossless formats
// ═══════════════════════════════════════════════════════════════════════

const (
	apeHeaderMagic = "APETAGEX"
	apeFooterSize  = 32
	apeHeaderSize  = 32
	apeFlagContainsHeader = 0x80000000
)

// APETagItem represents a single APEv2 tag item.
type APETagItem struct {
	Key      string
	Value    []byte
	Flag     uint32 // 0=utf8, 1=binary, 2=locator
}

// APETags holds parsed APEv2 tag data.
type APETags struct {
	Items    []APETagItem
	HasHeader bool
}

// ReadAPETags reads APEv2 tags from a file (FLAC, APE, WavPack, Musepack, MP3).
func ReadAPETags(path string) (*APETags, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	info, err := f.Stat()
	if err != nil {
		return nil, err
	}

	// APEv2 tag is at the end of the file (before ID3v1 if present)
	offset := info.Size()

	// Skip ID3v1 tag (128 bytes at end) if present
	id3v1 := make([]byte, 3)
	if _, err := f.ReadAt(id3v1, offset-128); err == nil && string(id3v1) == "TAG" {
		offset -= 128
	}

	// Read APEv2 footer
	if offset < apeFooterSize {
		return nil, fmt.Errorf("ape: file too small for APE tag")
	}
	footer := make([]byte, apeFooterSize)
	if _, err := f.ReadAt(footer, offset-apeFooterSize); err != nil {
		return nil, err
	}

	if string(footer[0:8]) != apeHeaderMagic {
		return nil, fmt.Errorf("ape: no APEv2 tag found")
	}

	size := int64(binary.LittleEndian.Uint32(footer[8:12]))
	version := binary.LittleEndian.Uint32(footer[12:16])
	numItems := int(binary.LittleEndian.Uint32(footer[16:20]))
	flags := binary.LittleEndian.Uint32(footer[20:24])

	if version != 2000 {
		return nil, fmt.Errorf("ape: unsupported APEv2 version %d", version)
	}

	hasHeader := flags&apeFlagContainsHeader != 0
	tagStart := offset - apeFooterSize - size
	if hasHeader {
		tagStart -= apeHeaderSize
	}

	if tagStart < 0 {
		return nil, fmt.Errorf("ape: invalid tag size")
	}

	// Read tag data
	tagData := make([]byte, size)
	if _, err := f.ReadAt(tagData, tagStart); err != nil {
		return nil, err
	}

	tags := &APETags{HasHeader: hasHeader}
	parsed, err := parseAPEItems(tagData, numItems)
	if err != nil {
		return nil, err
	}
	tags.Items = parsed
	return tags, nil
}

// ReadAPETagsFromReader reads APEv2 tags from an io.ReaderAt.
func ReadAPETagsFromReader(r io.ReaderAt, size int64) (*APETags, error) {
	if size < apeFooterSize {
		return nil, fmt.Errorf("ape: too small for APE tag")
	}

	footer := make([]byte, apeFooterSize)
	if _, err := r.ReadAt(footer, size-apeFooterSize); err != nil {
		return nil, err
	}

	if string(footer[0:8]) != apeHeaderMagic {
		return nil, fmt.Errorf("ape: no APEv2 tag found")
	}

	tagSize := int64(binary.LittleEndian.Uint32(footer[8:12]))
	numItems := int(binary.LittleEndian.Uint32(footer[16:20]))
	flags := binary.LittleEndian.Uint32(footer[20:24])
	hasHeader := flags&apeFlagContainsHeader != 0

	tagStart := size - apeFooterSize - tagSize
	if hasHeader {
		tagStart -= apeHeaderSize
	}
	if tagStart < 0 {
		return nil, fmt.Errorf("ape: invalid tag size")
	}

	tagData := make([]byte, tagSize)
	if _, err := r.ReadAt(tagData, tagStart); err != nil {
		return nil, err
	}

	tags := &APETags{HasHeader: hasHeader}
	parsed, err := parseAPEItems(tagData, numItems)
	if err != nil {
		return nil, err
	}
	tags.Items = parsed
	return tags, nil
}

func parseAPEItems(data []byte, numItems int) ([]APETagItem, error) {
	var items []APETagItem
	offset := 0
	for i := 0; i < numItems && offset < len(data); i++ {
		if offset+8 > len(data) {
			break
		}
		itemSize := int(binary.LittleEndian.Uint32(data[offset : offset+4]))
		itemFlag := binary.LittleEndian.Uint32(data[offset+4 : offset+8])
		offset += 8

		// Read null-terminated key
		keyStart := offset
		for offset < len(data) && data[offset] != 0 {
			offset++
		}
		if offset >= len(data) {
			break
		}
		key := string(data[keyStart:offset])
		offset++ // skip null

		// Read value
		if offset+itemSize > len(data) {
			break
		}
		value := make([]byte, itemSize)
		copy(value, data[offset:offset+itemSize])
		offset += itemSize

		items = append(items, APETagItem{
			Key:   strings.ToUpper(key),
			Value: value,
			Flag:  itemFlag,
		})
	}
	return items, nil
}

// Get returns the value for a key (case-insensitive).
func (t *APETags) Get(key string) string {
	key = strings.ToUpper(key)
	for _, item := range t.Items {
		if item.Key == key && item.Flag == 0 { // UTF-8 only
			return string(item.Value)
		}
	}
	return ""
}

// Set adds or replaces a tag item.
func (t *APETags) Set(key, value string) {
	key = strings.ToUpper(key)
	for i, item := range t.Items {
		if item.Key == key {
			t.Items[i].Value = []byte(value)
			t.Items[i].Flag = 0
			return
		}
	}
	t.Items = append(t.Items, APETagItem{
		Key:   key,
		Value: []byte(value),
		Flag:  0,
	})
}

// SetBinary adds or replaces a binary tag item (e.g. cover art).
func (t *APETags) SetBinary(key string, data []byte) {
	key = strings.ToUpper(key)
	for i, item := range t.Items {
		if item.Key == key {
			t.Items[i].Value = data
			t.Items[i].Flag = 1
			return
		}
	}
	t.Items = append(t.Items, APETagItem{
		Key:   key,
		Value: data,
		Flag:  1,
	})
}

// ToAudioMetadata converts APE tags to the standard Metadata struct.
func (t *APETags) ToAudioMetadata() *Metadata {
	m := &Metadata{}
	m.Title = t.Get("TITLE")
	m.Artist = t.Get("ARTIST")
	m.Album = t.Get("ALBUM")
	m.AlbumArtist = t.Get("ALBUMARTIST")
	m.Genre = t.Get("GENRE")
	m.ISRC = t.Get("ISRC")

	if v := t.Get("TRACK"); v != "" {
		fmt.Sscanf(v, "%d", &m.TrackNumber)
	}
	if v := t.Get("DISC"); v != "" {
		fmt.Sscanf(v, "%d", &m.DiscNumber)
	}
	if v := t.Get("DATE"); v != "" {
		fmt.Sscanf(v, "%d", &m.Year)
	}
	if v := t.Get("YEAR"); v != "" && m.Year == 0 {
		fmt.Sscanf(v, "%d", &m.Year)
	}
	return m
}

// WriteAPETags writes APEv2 tags to a file (header + footer).
func WriteAPETags(path string, tags *APETags) error {
	data := encodeAPEItems(tags.Items)

	// Build footer
	footer := make([]byte, apeFooterSize)
	copy(footer[0:8], apeHeaderMagic)
	binary.LittleEndian.PutUint32(footer[8:12], uint32(len(data)))
	binary.LittleEndian.PutUint32(footer[12:16], 2000) // version 2.0
	binary.LittleEndian.PutUint32(footer[16:20], uint32(len(tags.Items)))
	binary.LittleEndian.PutUint32(footer[20:24], apeFlagContainsHeader)

	// Build header (same as footer but with header flag)
	header := make([]byte, apeHeaderSize)
	copy(header[0:8], apeHeaderMagic)
	binary.LittleEndian.PutUint32(header[8:12], uint32(len(data)))
	binary.LittleEndian.PutUint32(header[12:16], 2000)
	binary.LittleEndian.PutUint32(header[16:20], uint32(len(tags.Items)))
	binary.LittleEndian.PutUint32(header[20:24], 0) // no footer flag

	// Read existing file
	existing, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	// Strip existing APE tag if present
	trimmed := stripAPEFromEnd(existing)

	// Write: header + data + footer + original content
	var buf bytes.Buffer
	buf.Write(header)
	buf.Write(data)
	buf.Write(footer)
	buf.Write(trimmed)

	return SafeSaveFLAC(path, buf.Bytes())
}

func encodeAPEItems(items []APETagItem) []byte {
	var buf bytes.Buffer
	for _, item := range items {
		keyBytes := []byte(strings.ToUpper(item.Key))
		buf.Write(keyBytes)
		buf.WriteByte(0)
		binary.Write(&buf, binary.LittleEndian, uint32(len(item.Value)))
		binary.Write(&buf, binary.LittleEndian, item.Flag)
		buf.Write(item.Value)
	}
	return buf.Bytes()
}

func stripAPEFromEnd(data []byte) []byte {
	// Check for ID3v1 at end
	offset := len(data)
	if offset >= 128 && string(data[offset-128:offset-125]) == "TAG" {
		offset -= 128
	}

	// Check for APEv2 footer
	if offset >= apeFooterSize {
		footer := data[offset-apeFooterSize : offset]
		if string(footer[0:8]) == apeHeaderMagic {
			size := int64(binary.LittleEndian.Uint32(footer[8:12]))
			flags := binary.LittleEndian.Uint32(footer[20:24])
			totalTagSize := size + apeFooterSize
			if flags&apeFlagContainsHeader != 0 {
				totalTagSize += apeHeaderSize
			}
			newOffset := offset - int(totalTagSize)
			if newOffset >= 0 {
				return data[:newOffset]
			}
		}
	}
	return data
}

// MergeAPEItems merges new items into existing, preserving non-overridden items.
func MergeAPEItems(existing, newItems []APETagItem) []APETagItem {
	merged := make([]APETagItem, len(existing))
	copy(merged, existing)

	for _, ni := range newItems {
		found := false
		for i, ei := range merged {
			if ei.Key == ni.Key {
				merged[i] = ni
				found = true
				break
			}
		}
		if !found {
			merged = append(merged, ni)
		}
	}
	return merged
}

// APEv2 key aliases for metadata field mapping.
var apeKeyAliases = map[string][]string{
	"DATE":         {"DATE", "YEAR", "RECORDDATE", "RECORDINGDATE"},
	"DISCNUMBER":   {"DISCNUMBER", "DISC", "DISKNUMBER"},
	"TRACKNUMBER":  {"TRACKNUMBER", "TRACK", "TRACKNUMBER"},
	"ALBUMARTIST":  {"ALBUMARTIST", "ALBUMARTIST", "ALBUMARTIST"},
	"COMPOSER":     {"COMPOSER", "COMPOSER"},
	"ISRC":         {"ISRC", "ISRC", "MUSICBRAINZ_ISRC"},
}

// apeKeysFromFields returns APE tag keys for standard metadata fields.
func apeKeysFromFields(field string) []string {
	if aliases, ok := apeKeyAliases[strings.ToUpper(field)]; ok {
		return aliases
	}
	return []string{strings.ToUpper(field)}
}
