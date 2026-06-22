package cue

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

func ParseCueFile(cuePath string) (*CueSheet, error) {
	f, err := os.Open(cuePath)
	if err != nil {
		return nil, fmt.Errorf("failed to open cue file: %w", err)
	}
	defer f.Close()

	sheet := &CueSheet{}
	var currentTrack *CueTrack

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		line = strings.TrimPrefix(line, "\xef\xbb\xbf")
		line = strings.TrimSpace(line)

		upper := strings.ToUpper(line)

		switch {
		case strings.HasPrefix(upper, "REM "):
			parseCueRemCommand(line, sheet, currentTrack)
		case strings.HasPrefix(upper, "PERFORMER "):
			parseCuePerformer(line, sheet, currentTrack)
		case strings.HasPrefix(upper, "TITLE "):
			parseCueTitle(line, sheet, currentTrack)
		case strings.HasPrefix(upper, "FILE "):
			parseCueFileEntry(line, sheet)
		case strings.HasPrefix(upper, "TRACK "):
			currentTrack = parseCueTrack(line, sheet, currentTrack)
		case strings.HasPrefix(upper, "INDEX ") && currentTrack != nil:
			parseCueIndex(line, currentTrack)
		case strings.HasPrefix(upper, "ISRC ") && currentTrack != nil:
			parseCueISRC(line, currentTrack)
		case strings.HasPrefix(upper, "SONGWRITER "):
			parseCueSongwriter(line, sheet, currentTrack)
		}
	}

	if currentTrack != nil {
		sheet.Tracks = append(sheet.Tracks, *currentTrack)
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error reading cue file: %w", err)
	}

	if len(sheet.Tracks) == 0 {
		return nil, fmt.Errorf("no tracks found in cue file")
	}

	return sheet, nil
}
