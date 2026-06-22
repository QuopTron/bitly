package metadata

import (
	"bytes"
	"strings"
)

func extractUserTextFrame(data []byte) (string, string) {
	if len(data) < 2 {
		return "", ""
	}
	encoding := data[0]
	payload := data[1:]
	var descRaw, valueRaw []byte
	switch encoding {
	case 1, 2:
		for i := 0; i+1 < len(payload); i += 2 {
			if payload[i] == 0 && payload[i+1] == 0 {
				descRaw = payload[:i]
				valueRaw = payload[i+2:]
				break
			}
		}
	default:
		idx := bytes.IndexByte(payload, 0)
		if idx >= 0 {
			descRaw = payload[:idx]
			if idx+1 <= len(payload) {
				valueRaw = payload[idx+1:]
			}
		}
	}
	if len(valueRaw) == 0 {
		return "", ""
	}
	descFramed := make([]byte, 1+len(descRaw))
	descFramed[0] = encoding
	copy(descFramed[1:], descRaw)
	valueFramed := make([]byte, 1+len(valueRaw))
	valueFramed[0] = encoding
	copy(valueFramed[1:], valueRaw)
	return strings.TrimSpace(extractTextFrame(descFramed)), strings.TrimSpace(extractTextFrame(valueFramed))
}

func isLyricsDescription(desc string) bool {
	switch strings.ToLower(strings.TrimSpace(desc)) {
	case "lyrics", "lyric", "unsyncedlyrics", "unsynced lyrics", "uslt", "lrc":
		return true
	}
	return false
}
