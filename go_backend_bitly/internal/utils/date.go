package utils

import (
	"regexp"
	"strconv"
	"strings"
	"time"
)

var yearPattern = regexp.MustCompile(`\d{4}`)

func ParseMetadataDate(rawDate string) (time.Time, bool) {
	clean := strings.TrimSpace(rawDate)
	if clean == "" {
		return time.Time{}, false
	}

	layouts := []string{
		time.RFC3339Nano,
		time.RFC3339,
		"2006-01-02",
		"2006-01",
		"2006",
		"2006/01/02",
		"2006/01",
		"2006.01.02",
		"2006.01",
	}

	for _, layout := range layouts {
		parsed, err := time.Parse(layout, clean)
		if err == nil {
			return parsed, true
		}
	}

	if len(clean) >= 10 {
		parsed, err := time.Parse("2006-01-02", clean[:10])
		if err == nil {
			return parsed, true
		}
	}

	yearMatch := yearPattern.FindString(clean)
	if yearMatch == "" {
		return time.Time{}, false
	}

	year, err := strconv.Atoi(yearMatch)
	if err != nil || year <= 0 {
		return time.Time{}, false
	}

	return time.Date(year, time.January, 1, 0, 0, 0, 0, time.UTC), true
}

func ExtractYear(date string) string {
	if len(date) >= 4 {
		return date[:4]
	}
	return date
}
