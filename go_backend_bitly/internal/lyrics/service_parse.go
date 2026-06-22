package lyrics

import (
	"encoding/json"
	"regexp"
	"strings"
)

func ParseSyncedLyrics(syncedLyrics string) []LyricsLine {
	var lines []LyricsLine
	lrcPattern := regexp.MustCompile(`\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)`)

	for _, line := range strings.Split(syncedLyrics, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		if strings.HasPrefix(line, "[bg:") && len(lines) > 0 {
			lines[len(lines)-1].Words = strings.TrimSpace(lines[len(lines)-1].Words + "\n" + line)
			continue
		}

		matches := lrcPattern.FindStringSubmatch(line)
		if len(matches) == 5 {
			startMs := LrcTimestampToMs(matches[1], matches[2], matches[3])
			words := strings.TrimSpace(matches[4])
			if words == "" {
				continue
			}
			lines = append(lines, LyricsLine{StartTimeMs: startMs, Words: words, EndTimeMs: 0})
		}
	}

	for i := 0; i < len(lines)-1; i++ {
		lines[i].EndTimeMs = lines[i+1].StartTimeMs
	}
	if len(lines) > 0 {
		lines[len(lines)-1].EndTimeMs = lines[len(lines)-1].StartTimeMs + 5000
	}
	return lines
}

func PlainTextLyricsLines(rawLyrics string) []LyricsLine {
	var lines []LyricsLine
	for _, line := range strings.Split(rawLyrics, "\n") {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" {
			continue
		}
		lines = append(lines, LyricsLine{StartTimeMs: 0, Words: trimmed, EndTimeMs: 0})
	}
	return lines
}

func PlainLyricsFromTimedLines(lines []LyricsLine) string {
	parts := make([]string, 0, len(lines))
	for _, line := range lines {
		words := strings.TrimSpace(line.Words)
		if words == "" {
			continue
		}
		parts = append(parts, words)
	}
	return strings.Join(parts, "\n")
}

func LyricsHasUsableText(lyrics *LyricsResponse) bool {
	if lyrics == nil {
		return false
	}
	if lyrics.Instrumental {
		return true
	}
	if strings.TrimSpace(lyrics.PlainLyrics) != "" {
		return true
	}
	for _, line := range lyrics.Lines {
		if strings.TrimSpace(line.Words) != "" {
			return true
		}
	}
	return false
}

func DetectLyricsErrorPayload(raw string) (string, bool) {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" || !strings.HasPrefix(trimmed, "{") {
		return "", false
	}
	var payload map[string]interface{}
	if err := json.Unmarshal([]byte(trimmed), &payload); err != nil {
		return "", false
	}

	lyricsKeys := []string{"lyrics", "lyric", "lrc", "content", "lines", "syncedLyrics", "unsyncedLyrics"}
	hasLyricsKey := false
	for _, key := range lyricsKeys {
		if _, ok := payload[key]; ok {
			hasLyricsKey = true
			break
		}
	}

	for _, key := range []string{"message", "error", "detail", "reason"} {
		if msg, ok := payload[key].(string); ok {
			msg = strings.TrimSpace(msg)
			if msg != "" && !hasLyricsKey {
				return msg, true
			}
		}
	}
	if success, ok := payload["success"].(bool); ok && !success && !hasLyricsKey {
		return "request unsuccessful", true
	}
	return "", false
}


