package download

import (
	"os"
	"path/filepath"
)

func CleanupStaging(dir string) int {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return 0
	}
	removed := 0
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		if filepath.Ext(e.Name()) == ".partial" {
			path := filepath.Join(dir, e.Name())
			if err := os.Remove(path); err == nil {
				removed++
			}
		}
	}
	return removed
}
