package lyrics

import (
	"encoding/json"
	"fmt"
	"strings"
)

type paxResponse struct {
	Type    string      `json:"type"`
	Content []paxLyrics `json:"content"`
}

type paxLyrics struct {
	Text           []paxLyricDetail `json:"text"`
	Timestamp      int              `json:"timestamp"`
	OppositeTurn   bool             `json:"oppositeTurn"`
	Background     bool             `json:"background"`
	BackgroundText []paxLyricDetail `json:"backgroundText"`
	EndTime        int              `json:"endtime"`
}

type paxLyricDetail struct {
	Text      string `json:"text"`
	Part      bool   `json:"part"`
	Timestamp *int   `json:"timestamp"`
	EndTime   *int   `json:"endtime"`
}

func formatPaxLyricsToLRC(rawJSON string, multiPersonWordByWord, preserveWordTiming bool) (string, error) {
	var paxResp paxResponse
	if err := json.Unmarshal([]byte(rawJSON), &paxResp); err == nil && paxResp.Content != nil {
		return formatPaxContent(paxResp.Type, paxResp.Content, multiPersonWordByWord, preserveWordTiming), nil
	}
	var directLyrics []paxLyrics
	if err := json.Unmarshal([]byte(rawJSON), &directLyrics); err == nil && len(directLyrics) > 0 {
		return formatPaxContent("Syllable", directLyrics, multiPersonWordByWord, preserveWordTiming), nil
	}
	return "", fmt.Errorf("failed to parse pax lyrics response")
}

func appendPaxLyricDetail(builder *strings.Builder, details []paxLyricDetail, preserveWordTiming bool) {
	lastStart := ""
	for _, syllable := range details {
		if preserveWordTiming && syllable.Timestamp != nil {
			t := fmt.Sprintf("<%s>", strings.TrimPrefix(MsToLRCTimestamp(int64(*syllable.Timestamp)), "["))
			t = strings.TrimSuffix(t, "]")
			if t != lastStart {
				builder.WriteString(t)
				lastStart = t
			}
		}
		builder.WriteString(syllable.Text)
		if !syllable.Part {
			builder.WriteString(" ")
		}
		if preserveWordTiming && syllable.EndTime != nil {
			t := fmt.Sprintf("<%s>", strings.TrimPrefix(MsToLRCTimestamp(int64(*syllable.EndTime)), "["))
			t = strings.TrimSuffix(t, "]")
			builder.WriteString(t)
		}
	}
}

func formatPaxContent(lyricsType string, content []paxLyrics, multiPersonWordByWord, preserveWordTiming bool) string {
	var sb strings.Builder
	for i, line := range content {
		if i > 0 {
			sb.WriteString("\n")
		}
		timestamp := MsToLRCTimestamp(int64(line.Timestamp))

		if strings.EqualFold(lyricsType, "Syllable") {
			sb.WriteString(timestamp)
			if multiPersonWordByWord {
				if line.OppositeTurn {
					sb.WriteString("v2:")
				} else {
					sb.WriteString("v1:")
				}
			}
			appendPaxLyricDetail(&sb, line.Text, preserveWordTiming)
			if line.Background && multiPersonWordByWord && len(line.BackgroundText) > 0 {
				sb.WriteString("\n[bg:")
				appendPaxLyricDetail(&sb, line.BackgroundText, preserveWordTiming)
				sb.WriteString("]")
			}
		} else if len(line.Text) > 0 {
			sb.WriteString(timestamp)
			sb.WriteString(line.Text[0].Text)
		}
	}
	return strings.TrimSpace(sb.String())
}


