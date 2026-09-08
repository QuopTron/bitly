package gobackend

import (
	"crypto/sha1"
	"encoding/hex"
	"os"
	"regexp"
	"strings"
)

// writeFileAtomic writes content to path via a temp file + rename.
func writeFileAtomic(path, content string) error {
	tmp := path + ".dl-tmp"
	if err := os.WriteFile(tmp, []byte(content), 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

// sha1Hex returns the hex SHA-1 of a string, matching Flutter's lyrics_ prefix.
func sha1Hex(s string) string {
	h := sha1.Sum([]byte(s))
	return hex.EncodeToString(h[:])
}

// sanitizeFileName strips characters unsafe for filesystems.
func sanitizeFileName(s string) string {
	s = strings.TrimSpace(s)
	re := regexp.MustCompile(`[\\/:*?"<>|]`)
	s = re.ReplaceAllString(s, "_")
	s = strings.TrimRight(s, ". ")
	if s == "" {
		return "unknown"
	}
	return s
}
