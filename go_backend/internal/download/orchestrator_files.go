package download

import (
	"log"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

var invalidFileChars = regexp.MustCompile(`[<>:"/\\|?*\x00-\x1F]`)

func sanitizarNombreArchivo(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return "unknown"
	}
	s = invalidFileChars.ReplaceAllString(s, "_")
	s = strings.TrimRight(s, ". ")
	if s == "" {
		return "unknown"
	}
	return s
}

// finalizeDownloadFile renames a freshly produced download/decrypt file from its
// temporary ".tmp." name to a clean {itemID}{ext} basename. The winner of the
// parallel race then has a stable, reusable name (StreamCacheFile matches it)
// and stays clearly distinct from the partial ".tmp." companions left by other
// candidates. Files already clean are returned untouched.
func finalizarArchivoDescarga(outDir, itemID, filePath string) string {
	if filePath == "" {
		return ""
	}
	ext := filepath.Ext(filePath)
	if ext == "" {
		return filePath
	}
	clean := filepath.Join(outDir, sanitizarNombreArchivo(itemID)+ext)
	log.Printf("[finalize] itemID=%q src=%q -> %q", itemID, filePath, clean)
	if clean == filePath {
		return filePath
	}
	_ = os.Remove(clean)
	if err := os.Rename(filePath, clean); err == nil {
		return clean
	}
	return filePath
}

// StreamCacheFile returns the path of an already-produced stream-cache file for
// itemID (the same basename the download pipeline writes via sanitizeFilename),
// or "" if none exists. Letting repeated plays reuse the previously downloaded
// file makes the second invitation instant instead of re-downloading and
// re-converting from scratch.
func StreamCacheFile(dir, itemID string) string {
	if dir == "" || itemID == "" {
		return ""
	}
	base := sanitizarNombreArchivo(itemID) + "."
	entries, err := os.ReadDir(dir)
	if err != nil {
		return ""
	}
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		if !strings.HasPrefix(e.Name(), base) {
			continue
		}
		// Skip in-flight partial downloads. With parallel download plans several
		// providers may converge on the same itemId simultaneously; each writes
		// to a unique ".tmp."-suffixed file and only the winner keeps a clean
		// final file, so a partial/aborted companion must never be served or
		// treated as a complete cache entry.
		if strings.Contains(e.Name(), ".tmp.") {
			continue
		}
		full := filepath.Join(dir, e.Name())
		// Only serve files media_kit can actually decode. A stale/protected
		// file (e.g. an encrypted mp4 left with a .flac name) would reopen
		// forever and block playback, so invalid files are deleted and the
		// next tap re-downloads a fresh, verified copy.
		if esArchivoCacheReproducible(full) {
			return full
		}
		_ = os.Remove(full)
	}
	return ""
}
