package lyrics

import (
	"regexp"
	"strings"
)

func SimplifyTrackName(name string) string {
	patterns := []string{
		`\s*\(feat\..*?\)`,
		`\s*\(ft\..*?\)`,
		`\s*\(featuring.*?\)`,
		`\s*\(with.*?\)`,
		`\s*-\s*Remaster(ed)?.*$`,
		`\s*-\s*\d{4}\s*Remaster.*$`,
		`\s*\(Remaster(ed)?.*?\)`,
		`\s*\(Deluxe.*?\)`,
		`\s*\(Bonus.*?\)`,
		`\s*\(Live.*?\)`,
		`\s*\(Acoustic.*?\)`,
		`\s*\(Radio Edit\)`,
		`\s*\(Single Version\)`,
	}
	result := name
	for _, pattern := range patterns {
		re := regexp.MustCompile("(?i)" + pattern)
		result = re.ReplaceAllString(result, "")
	}
	result = strings.TrimSpace(result)
	return result
}

func NormalizeArtistName(name string) string {
	separators := []string{
		" feat. ", " ft. ", " featuring ", " with ",
		", ", "; ", " & ", " vs ", " presents ", " presentó ",
		" y ", " x ",
	}
	lower := strings.ToLower(name)
	for _, sep := range separators {
		if idx := strings.Index(lower, sep); idx > 0 {
			return strings.TrimSpace(name[:idx])
		}
	}
	return strings.TrimSpace(name)
}

func isLikelyInstrumentalTrack(name string) bool {
	trimmed := strings.TrimSpace(name)
	if trimmed == "" {
		return false
	}
	return instrumentalTrackPattern.MatchString(trimmed)
}
