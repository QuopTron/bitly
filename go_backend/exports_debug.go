package gobackend

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"runtime/pprof"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend/internal/download"
)

// DumpGoroutines writes a full goroutine stack dump to [path] (or, when empty,
// to <downloadDir>/goroutines_dump.txt) and logs a short summary. Called by the
// Android bridge when a Go RPC times out: the dump shows exactly which JS call
// / sandbox lock is holding the executor, so a stuck call is diagnosable from
// the device instead of being a silent black box.
func DumpGoroutines(path string) string {
	dir := downloadDir
	if dir == "" {
		dir = download.GlobalOutputDir()
	}
	if dir == "" {
		dir = os.TempDir()
	}
	if path == "" {
		path = filepath.Join(dir, "goroutines_dump.txt")
	}
	var buf strings.Builder
	buf.WriteString(fmt.Sprintf("=== goroutine dump %s ===\n", time.Now().Format(time.RFC3339)))
	_ = pprof.Lookup("goroutine").WriteTo(&buf, 1)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err == nil {
		if err := os.WriteFile(path, []byte(buf.String()), 0o644); err != nil {
			log.Printf("[goroutine-dump] write failed: %v", err)
		}
	}
	count := 0
	var summary []string
	for _, l := range strings.Split(buf.String(), "\n") {
		if strings.HasPrefix(l, "goroutine ") {
			count++
			if len(summary) < 10 {
				summary = append(summary, strings.TrimSpace(l))
			}
		}
	}
	log.Printf("[goroutine-dump] wrote %s (%d goroutines) %s", path, count, strings.Join(summary, " | "))
	return fmt.Sprintf(`{"ok":true,"file":"%s","goroutines":%d}`, path, count)
}