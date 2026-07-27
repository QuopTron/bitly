// Package cue parses CUE sheet files for gapless playback and splitting.
package cue

import (
	"fmt"
	"strconv"
	"strings"
)

// Sheet represents a parsed CUE sheet.
type Sheet struct {
	Title      string  `json:"title"`
	Artist     string  `json:"artist"`
	Performer  string  `json:"performer"`
	File       string  `json:"file"`
	FileType   string  `json:"fileType"`
	Tracks     []Track `json:"tracks"`
}

// Track represents a single track in a CUE sheet.
type Track struct {
	Number    int    `json:"number"`
	Title     string `json:"title"`
	Artist    string `json:"artist"`
	Performer string `json:"performer"`
	Isrc      string `json:"isrc"`
	StartTime string `json:"startTime"` // MM:SS:FF format
	StartMs   int    `json:"startMs"`
	EndMs     int    `json:"endMs"`
}

// Parse parses a CUE sheet string into a Sheet struct.
func Parse(cueData string) (*Sheet, error) {
	sheet := &Sheet{}
	lines := strings.Split(cueData, "\n")
	var currentTrack *Track

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}

		switch {
		case strings.HasPrefix(strings.ToUpper(line), "TITLE "):
			title := extractQuoted(line)
			if currentTrack != nil {
				currentTrack.Title = title
			} else {
				sheet.Title = title
			}

		case strings.HasPrefix(strings.ToUpper(line), "PERFORMER "):
			performer := extractQuoted(line)
			if currentTrack != nil {
				currentTrack.Performer = performer
			} else {
				sheet.Performer = performer
			}

		case strings.HasPrefix(strings.ToUpper(line), "FILE "):
			parts := strings.SplitN(line, " ", 3)
			if len(parts) >= 3 {
				sheet.File = extractQuoted(parts[1])
				sheet.FileType = strings.TrimSpace(parts[len(parts)-1])
			}

		case strings.HasPrefix(strings.ToUpper(line), "TRACK "):
			parts := strings.Fields(line)
			if currentTrack != nil && currentTrack.Number > 0 {
				// Calculate end time as start of next track
				sheet.Tracks = append(sheet.Tracks, *currentTrack)
			}
			currentTrack = &Track{}
			if len(parts) >= 2 {
				currentTrack.Number, _ = strconv.Atoi(parts[1])
			}

		case strings.HasPrefix(strings.ToUpper(line), "INDEX 01 "):
			if currentTrack != nil {
				timeStr := strings.TrimPrefix(line, "INDEX 01 ")
				currentTrack.StartTime = strings.TrimSpace(timeStr)
				currentTrack.StartMs = timeToMs(strings.TrimSpace(timeStr))
				// Set previous track's end time
				if len(sheet.Tracks) > 0 {
					sheet.Tracks[len(sheet.Tracks)-1].EndMs = currentTrack.StartMs
				}
			}

		case strings.HasPrefix(strings.ToUpper(line), "ISRC "):
			if currentTrack != nil {
				currentTrack.Isrc = strings.TrimSpace(strings.TrimPrefix(line, "ISRC "))
			}
		}
	}

	if currentTrack != nil && currentTrack.Number > 0 {
		sheet.Tracks = append(sheet.Tracks, *currentTrack)
	}

	if len(sheet.Tracks) == 0 {
		return nil, fmt.Errorf("cue: no tracks found")
	}
	return sheet, nil
}

func extractQuoted(s string) string {
	start := strings.Index(s, "\"")
	if start == -1 {
		return strings.TrimSpace(s[strings.Index(s, " ")+1:])
	}
	end := strings.LastIndex(s, "\"")
	if end <= start {
		return s[start+1:]
	}
	return s[start+1 : end]
}

func timeToMs(timeStr string) int {
	parts := strings.Split(timeStr, ":")
	if len(parts) < 2 {
		return 0
	}
	mins, _ := strconv.Atoi(parts[0])
	secs, _ := strconv.Atoi(parts[1])
	frames := 0
	if len(parts) >= 3 {
		frames, _ = strconv.Atoi(parts[2])
	}
	return (mins*60 + secs) * 1000 + frames * 1000 / 75
}
