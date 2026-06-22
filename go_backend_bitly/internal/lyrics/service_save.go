package lyrics

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

func SaveLRCFile(audioFilePath, lrcContent string) (string, error) {
	if lrcContent == "" {
		return "", fmt.Errorf("empty LRC content")
	}
	dir := filepath.Dir(audioFilePath)
	ext := filepath.Ext(audioFilePath)
	baseName := strings.TrimSuffix(filepath.Base(audioFilePath), ext)
	lrcFilePath := filepath.Join(dir, baseName+".lrc")
	if err := os.WriteFile(lrcFilePath, []byte(lrcContent), 0644); err != nil {
		return "", fmt.Errorf("failed to write LRC file: %w", err)
	}
	return lrcFilePath, nil
}
