package utils

import "strings"

func FormatDateWithPattern(rawDate string, strftimePattern string) string {
	if rawDate == "" || strftimePattern == "" {
		return ""
	}

	parsedDate, ok := ParseMetadataDate(rawDate)
	if !ok {
		return ""
	}

	goLayout := ConvertStrftimeToGoLayout(strftimePattern)
	if goLayout == "" {
		return ""
	}

	return parsedDate.Format(goLayout)
}

func ConvertStrftimeToGoLayout(pattern string) string {
	if pattern == "" {
		return ""
	}

	var builder strings.Builder
	for i := 0; i < len(pattern); i++ {
		ch := pattern[i]
		if ch != '%' {
			builder.WriteByte(ch)
			continue
		}

		if i+1 >= len(pattern) {
			builder.WriteByte('%')
			break
		}

		i++
		switch pattern[i] {
		case 'Y':
			builder.WriteString("2006")
		case 'y':
			builder.WriteString("06")
		case 'm':
			builder.WriteString("01")
		case 'd':
			builder.WriteString("02")
		case 'b':
			builder.WriteString("Jan")
		case 'B':
			builder.WriteString("January")
		case '%':
			builder.WriteByte('%')
		default:
			builder.WriteByte('%')
			builder.WriteByte(pattern[i])
		}
	}

	return builder.String()
}
