package youtube

import "strings"

// splitLines splits NDJSON output into non-empty lines.
func splitLines(out string) []string {
	lines := strings.Split(out, "\n")
	result := make([]string, 0, len(lines))
	for _, l := range lines {
		if trimmed := strings.TrimSpace(l); trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return result
}

// firstJSONLine extracts the first JSON line from yt-dlp output (may contain warnings).
func firstJSONLine(out string) string {
	for _, line := range splitLines(out) {
		if strings.HasPrefix(line, "{") {
			return line
		}
	}
	return ""
}

// nonEmpty returns the first non-empty string.
func nonEmpty(vals ...string) string {
	for _, v := range vals {
		if v != "" {
			return v
		}
	}
	return ""
}
