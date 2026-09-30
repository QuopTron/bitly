package gobackend

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend/internal/download"
)

// streamCacheDirPath returns the directory for stream-fallback audio files.
// Lives inside the user's download dir so it follows the chosen storage
// location, mirroring the normal download folder logic.
func streamCacheDirPath() string {
	base := getDownloadDir()
	if base == "" {
		base = download.GlobalOutputDir()
	}
	if base == "" {
		base = os.TempDir()
	}
	return filepath.Join(base, ".stream_cache")
}

// evictStreamCache bounds the stream cache to the configured MB cap (or the
// plan limit when unset) and to a sane file count, deleting the oldest files
// first so repeated fallback downloads don't fill the disk.
func evictarCacheStream(dir string) {
	limitMB := getStreamCacheMaxMB()
	if limitMB <= 0 {
		limitMB = streamCacheLevelLimitMB()
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	type f struct {
		path string
		mod  time.Time
		size int64
	}
	var files []f
	var total int64
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		info, err := e.Info()
		if err != nil {
			continue
		}
		files = append(files, f{filepath.Join(dir, e.Name()), info.ModTime(), info.Size()})
		total += info.Size()
	}
	if len(files) == 0 {
		return
	}
	sort.Slice(files, func(i, j int) bool { return files[i].mod.Before(files[j].mod) })
	maxBytes := int64(limitMB) * 1024 * 1024
	const maxFiles = 60
	for i := 0; i < len(files); i++ {
		remaining := len(files) - i
		if remaining <= maxFiles && total <= maxBytes {
			break
		}
		if os.Remove(files[i].path) == nil {
			total -= files[i].size
		}
	}
}

// DeleteStreamCacheFile borra el audio cacheado en .stream_cache del track
// indicado: recibe {"id":"<trackId>"} y devuelve {"ok":true,"borrados":N}.
//
// Reemplaza el DELETE http://127.0.0.1:55009/cache/delete/<id>.flac que
// Flutter enviaba directamente: esa ruta nunca existió en el servidor (404
// permanente que el catch tragaba en silencio) y en Android/iOS ni siquiera
// había un servidor HTTP al que hablar. Como RPC funciona en todas las
// plataformas, incluida la web.
func DeleteStreamCacheFile(payload string) string {
	var req struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal([]byte(payload), &req); err != nil {
		return `{"ok":false,"error":"payload invalido"}`
	}
	req.ID = strings.TrimSpace(req.ID)
	if req.ID == "" || strings.ContainsAny(req.ID, `/\`) || strings.Contains(req.ID, "..") {
		return `{"ok":false,"error":"id invalido"}`
	}
	borrados := download.StreamCacheBorrar(streamCacheDirPath(), req.ID)
	return fmt.Sprintf(`{"ok":true,"borrados":%d}`, borrados)
}
