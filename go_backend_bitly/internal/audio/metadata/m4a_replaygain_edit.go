package metadata

import (
	"fmt"
	"os"
	"strings"
)

// EditM4AReplayGain edits ReplayGain fields in an M4A file.
func EditM4AReplayGain(filePath string, fields map[string]string) error {
	replayGainFields := collectM4AReplayGainFields(fields)
	if len(replayGainFields) == 0 {
		return nil
	}

	f, err := os.Open(filePath)
	if err != nil {
		return err
	}
	defer f.Close()

	info, err := f.Stat()
	if err != nil {
		return err
	}

	path, err := findM4AMetadataPath(f, info.Size())
	if err != nil {
		return err
	}

	data, err := os.ReadFile(filePath)
	if err != nil {
		return err
	}

	bodyStart := path.ilst.offset + path.ilst.headerSize
	bodyEnd := path.ilst.offset + path.ilst.size
	newBody := make([]byte, 0, int(path.ilst.size))
	targets := map[string]struct{}{
		"REPLAYGAIN_TRACK_GAIN": {},
		"REPLAYGAIN_TRACK_PEAK": {},
		"REPLAYGAIN_ALBUM_GAIN": {},
		"REPLAYGAIN_ALBUM_PEAK": {},
		"ITUNNORM":              {},
	}

	for pos := bodyStart; pos+8 <= bodyEnd; {
		header, readErr := readAtomHeaderAt(f, pos, info.Size())
		if readErr != nil {
			return readErr
		}
		if header.size == 0 {
			header.size = bodyEnd - pos
		}
		if header.size < header.headerSize {
			return fmt.Errorf("invalid atom size for %s", header.typ)
		}

		keep := true
		if header.typ == "----" {
			name, _, freeformErr := readM4AFreeformValue(f, header, info.Size())
			if freeformErr == nil {
				if _, ok := targets[strings.ToUpper(strings.TrimSpace(name))]; ok {
					keep = false
				}
			}
		}
		if keep {
			newBody = append(newBody, data[pos:pos+header.size]...)
		}
		pos += header.size
	}

	order := []string{"replaygain_track_gain", "replaygain_track_peak",
		"replaygain_album_gain", "replaygain_album_peak", "iTunNORM"}
	for _, key := range order {
		value := strings.TrimSpace(replayGainFields[key])
		if value == "" {
			continue
		}
		name := key
		if key != "iTunNORM" {
			name = strings.ToLower(key)
		}
		newBody = append(newBody, buildM4AFreeformAtom(name, value)...)
	}

	newIlst := buildM4AAtom("ilst", newBody)
	updated := append([]byte{}, data[:path.ilst.offset]...)
	updated = append(updated, newIlst...)
	updated = append(updated, data[path.ilst.offset+path.ilst.size:]...)

	delta := int64(len(newIlst)) - path.ilst.size
	if err := writeAtomSize(updated, path.ilst, path.ilst.size+delta); err != nil {
		return err
	}
	if err := writeAtomSize(updated, path.meta, path.meta.size+delta); err != nil {
		return err
	}
	if path.udta != nil {
		if err := writeAtomSize(updated, *path.udta, path.udta.size+delta); err != nil {
			return err
		}
	}
	if err := writeAtomSize(updated, path.moov, path.moov.size+delta); err != nil {
		return err
	}
	return os.WriteFile(filePath, updated, 0644)
}
