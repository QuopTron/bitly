package metadata

import (
	"bytes"
	"strings"
)

func extractTextFrame(data []byte) string {
	if len(data) == 0 {
		return ""
	}
	encoding := data[0]
	text := data[1:]
	switch encoding {
	case 0:
		return strings.TrimRight(string(text), "\x00")
	case 1:
		return decodeUTF16(text)
	case 2:
		return decodeUTF16BE(text)
	default:
		return strings.TrimRight(string(text), "\x00")
	}
}

func extractCommentFrame(data []byte) string {
	if len(data) < 5 {
		return ""
	}
	encoding := data[0]
	rest := data[4:]
	var text []byte
	switch encoding {
	case 1, 2:
		for i := 0; i+1 < len(rest); i += 2 {
			if rest[i] == 0 && rest[i+1] == 0 {
				text = rest[i+2:]
				break
			}
		}
	default:
		idx := bytes.IndexByte(rest, 0)
		if idx >= 0 && idx+1 < len(rest) {
			text = rest[idx+1:]
		} else {
			text = rest
		}
	}
	if len(text) == 0 {
		return ""
	}
	framed := make([]byte, 1+len(text))
	framed[0] = encoding
	copy(framed[1:], text)
	return extractTextFrame(framed)
}

func extractLyricsFrame(data []byte) string {
	if len(data) < 5 {
		return ""
	}
	encoding := data[0]
	rest := data[4:]
	var text []byte
	switch encoding {
	case 1, 2:
		for i := 0; i+1 < len(rest); i += 2 {
			if rest[i] == 0 && rest[i+1] == 0 {
				text = rest[i+2:]
				break
			}
		}
	default:
		idx := bytes.IndexByte(rest, 0)
		if idx >= 0 && idx+1 < len(rest) {
			text = rest[idx+1:]
		} else {
			text = rest
		}
	}
	if len(text) == 0 {
		return ""
	}
	framed := make([]byte, 1+len(text))
	framed[0] = encoding
	copy(framed[1:], text)
	return extractTextFrame(framed)
}
