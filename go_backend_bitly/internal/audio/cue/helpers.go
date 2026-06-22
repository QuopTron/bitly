package cue

import (
	"regexp"
	"strconv"
	"strings"
)

var (
	reRemCommand = regexp.MustCompile(`^REM\s+(\S+)\s+(.+)$`)
	reQuoted     = regexp.MustCompile(`"([^"]*)"`)
)

func parseCueTimestamp(ts string) float64 {
	parts := strings.Split(ts, ":")
	if len(parts) != 3 {
		return 0
	}

	minutes, _ := strconv.Atoi(parts[0])
	seconds, _ := strconv.Atoi(parts[1])
	frames, _ := strconv.Atoi(parts[2])

	return float64(minutes)*60 + float64(seconds) + float64(frames)/75.0
}

func unquoteCue(s string) string {
	s = strings.TrimSpace(s)
	if matches := reQuoted.FindStringSubmatch(s); len(matches) == 2 {
		return matches[1]
	}
	return s
}

func parseCueFileLine(rest string) (string, string) {
	rest = strings.TrimSpace(rest)

	var filename, ftype string

	if strings.HasPrefix(rest, "\"") {
		endQuote := strings.Index(rest[1:], "\"")
		if endQuote >= 0 {
			filename = rest[1 : endQuote+1]
			remaining := strings.TrimSpace(rest[endQuote+2:])
			ftype = remaining
		} else {
			filename = rest
		}
	} else {
		parts := strings.Fields(rest)
		if len(parts) >= 2 {
			ftype = parts[len(parts)-1]
			filename = strings.Join(parts[:len(parts)-1], " ")
		} else if len(parts) == 1 {
			filename = parts[0]
		}
	}

	return filename, strings.TrimSpace(ftype)
}
