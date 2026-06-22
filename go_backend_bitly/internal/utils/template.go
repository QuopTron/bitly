package utils

import (
	"regexp"
	"strconv"
	"strings"
)

var (
	formattedNumberPlaceholderExpr = regexp.MustCompile(`\{(track|disc):([0-9]+)\}`)
	dateFormatPlaceholderExpr      = regexp.MustCompile(`\{date:([^{}]+)\}`)
)

func BuildFilenameFromTemplate(template string, metadata map[string]interface{}) string {
	if template == "" {
		template = "{artist} - {title}"
	}

	result := replaceFormattedNumberPlaceholders(template, metadata)
	result = replaceDateFormatPlaceholders(result, metadata)

	dateValue := getDateValue(metadata)
	yearValue := getString(metadata, "year")
	if yearValue == "" {
		yearValue = ExtractYear(dateValue)
	}

	placeholders := map[string]string{
		"{title}":     getString(metadata, "title"),
		"{artist}":    getString(metadata, "artist"),
		"{album}":     getString(metadata, "album"),
		"{track}":     FormatTrackNumber(getInt(metadata, "track")),
		"{track_raw}": FormatRawNumber(getInt(metadata, "track")),
		"{year}":      yearValue,
		"{date}":      dateValue,
		"{disc}":      FormatDiscNumber(getInt(metadata, "disc")),
		"{disc_raw}":  FormatRawNumber(getInt(metadata, "disc")),
	}

	for placeholder, value := range placeholders {
		result = strings.ReplaceAll(result, placeholder, value)
	}

	return result
}

func replaceFormattedNumberPlaceholders(template string, metadata map[string]interface{}) string {
	return formattedNumberPlaceholderExpr.ReplaceAllStringFunc(template, func(match string) string {
		parts := formattedNumberPlaceholderExpr.FindStringSubmatch(match)
		if len(parts) != 3 {
			return ""
		}

		number := getInt(metadata, parts[1])
		width, err := strconv.Atoi(parts[2])
		if err != nil {
			return ""
		}

		return FormatNumberWithWidth(number, width)
	})
}

func replaceDateFormatPlaceholders(template string, metadata map[string]interface{}) string {
	return dateFormatPlaceholderExpr.ReplaceAllStringFunc(template, func(match string) string {
		parts := dateFormatPlaceholderExpr.FindStringSubmatch(match)
		if len(parts) != 2 {
			return ""
		}

		return FormatDateWithPattern(getDateValue(metadata), parts[1])
	})
}
