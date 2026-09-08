package download

import (
	"encoding/base64"
	"encoding/hex"
	"regexp"
	"strings"
)

var hexOnly = regexp.MustCompile(`^[0-9a-fA-F]+$`)

func candidatosClaveDescifrado(rawKey string) []string {
	out := map[string]struct{}{}
	addHex := func(k string) {
		k = strings.ToLower(strings.TrimSpace(k))
		if len(k) != 32 || !hexOnly.MatchString(k) {
			return
		}
		out[k] = struct{}{}
	}

	trimmed := strings.TrimSpace(rawKey)
	if trimmed == "" {
		return nil
	}

	noPrefix := trimmed
	if len(trimmed) >= 2 && (strings.HasPrefix(trimmed, "0x") || strings.HasPrefix(trimmed, "0X")) {
		noPrefix = trimmed[2:]
	}

	compact := strings.Map(func(r rune) rune {
		if (r >= '0' && r <= '9') || (r >= 'a' && r <= 'f') || (r >= 'A' && r <= 'F') {
			return r
		}
		return -1
	}, noPrefix)
	addHex(compact)

	if b, err := base64.StdEncoding.DecodeString(strings.ReplaceAll(noPrefix, " ", "")); err == nil {
		addHex(hex.EncodeToString(b))
	}

	addHex(noPrefix)
	if len(trimmed) == 32 || len(trimmed) == 16 {
		addHex(trimmed)
	}

	if len(out) == 0 {
		return nil
	}
	res := make([]string, 0, len(out))
	for k := range out {
		res = append(res, k)
	}
	return res
}

// isPlainAudioFile reports whether [path] starts with a recognizable plain
// audio container header: FLAC ("fLaC"), MP3 ("ID3"), Ogg/Opus ("OggS") or
// WAV ("RIFF"). Providers sometimes mark a download as encrypted and supply a
// decryption key even when the served stream is actually a plain, playable
// file (e.g. amazon/zarz returning a plain FLAC with a stale key). Such files
// must be served directly — feeding them to the mov-key decryptor only fails
// with "moov atom not found" because there is no MP4 to decrypt.
