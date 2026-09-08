package gobackend

import (
	"encoding/base64"
	"os"
)

func safeFixtureName(id string) string {
	out := make([]byte, 0, len(id))
	for _, c := range id {
		switch {
		case c >= 'a' && c <= 'z', c >= 'A' && c <= 'Z', c >= '0' && c <= '9', c == '_', c == '-':
			out = append(out, byte(c))
		default:
			out = append(out, '_')
		}
	}
	return string(out)
}

func copyFixtureFile(src, dst string) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	return os.WriteFile(dst, data, 0o644)
}

func clearPrefix(path string) string {
	data, err := os.ReadFile(path)
	if err != nil || len(data) == 0 {
		return ""
	}
	n := len(data)
	if n > 512 {
		n = 512
	}
	return base64.StdEncoding.EncodeToString(data[:n])
}
