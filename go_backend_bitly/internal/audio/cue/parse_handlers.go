package cue

import (
	"strconv"
	"strings"
)

func parseCueRemCommand(line string, sheet *CueSheet, track *CueTrack) {
	matches := reRemCommand.FindStringSubmatch(line)
	if len(matches) != 3 {
		return
	}
	key := strings.ToUpper(matches[1])
	value := unquoteCue(matches[2])
	switch key {
	case "GENRE":
		sheet.Genre = value
	case "DATE":
		sheet.Date = value
	case "COMMENT":
		sheet.Comment = value
	case "COMPOSER":
		if track != nil {
			track.Composer = value
		} else {
			sheet.Composer = value
		}
	}
}

func parseCuePerformer(line string, sheet *CueSheet, track *CueTrack) {
	value := unquoteCue(line[len("PERFORMER "):])
	if track != nil {
		track.Performer = value
	} else {
		sheet.Performer = value
	}
}

func parseCueTitle(line string, sheet *CueSheet, track *CueTrack) {
	value := unquoteCue(line[len("TITLE "):])
	if track != nil {
		track.Title = value
	} else {
		sheet.Title = value
	}
}

func parseCueFileEntry(line string, sheet *CueSheet) {
	rest := line[len("FILE "):]
	sheet.FileName, sheet.FileType = parseCueFileLine(rest)
}

func parseCueTrack(line string, sheet *CueSheet, currentTrack *CueTrack) *CueTrack {
	if currentTrack != nil {
		sheet.Tracks = append(sheet.Tracks, *currentTrack)
	}
	parts := strings.Fields(line)
	trackNum := 0
	if len(parts) >= 2 {
		trackNum, _ = strconv.Atoi(parts[1])
	}
	return &CueTrack{Number: trackNum, PreGap: -1}
}

func parseCueIndex(line string, track *CueTrack) {
	parts := strings.Fields(line)
	if len(parts) < 3 {
		return
	}
	indexNum, _ := strconv.Atoi(parts[1])
	timeSec := parseCueTimestamp(parts[2])
	switch indexNum {
	case 0:
		track.PreGap = timeSec
	case 1:
		track.StartTime = timeSec
	}
}

func parseCueISRC(line string, track *CueTrack) {
	track.ISRC = strings.TrimSpace(line[len("ISRC "):])
}

func parseCueSongwriter(line string, sheet *CueSheet, track *CueTrack) {
	value := unquoteCue(line[len("SONGWRITER "):])
	if track != nil {
		track.Composer = value
	} else {
		sheet.Composer = value
	}
}
