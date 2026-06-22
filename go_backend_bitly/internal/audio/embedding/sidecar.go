package embedding

import (
	"log"
	"os"
	"path/filepath"
	"strings"
)

func (e *Embedder) embedSidecar(req EmbedRequest) error {
	if req.CoverPath != "" {
		coverData, err := os.ReadFile(req.CoverPath)
		if err != nil {
			log.Printf("[Embedder] Warning: could not read cover %s: %v", req.CoverPath, err)
		} else {
			coverExt := filepath.Ext(req.CoverPath)
			if err := writeSidecarBytes(req.AudioPath, coverExt, coverData); err != nil {
				log.Printf("[Embedder] Warning: sidecar cover: %v", err)
			}
		}
	}
	if req.Lyrics != "" {
		if err := writeSidecar(req.AudioPath, ".lrc", req.Lyrics); err != nil {
			log.Printf("[Embedder] Warning: sidecar lyrics: %v", err)
		}
	}
	return nil
}

func (e *Embedder) resolveCoverPath(audioPath string) string {
	if e.coverDir == "" {
		return ""
	}
	base := strings.TrimSuffix(filepath.Base(audioPath), filepath.Ext(audioPath))
	for _, ext := range []string{".jpg", ".png", ".webp"} {
		p := filepath.Join(e.coverDir, base+ext)
		if info, err := os.Stat(p); err == nil && !info.IsDir() {
			return p
		}
	}
	return ""
}

func writeSidecar(audioPath, ext, content string) error {
	sidecarPath := strings.TrimSuffix(audioPath, filepath.Ext(audioPath)) + ext
	return os.WriteFile(sidecarPath, []byte(content), 0644)
}

func writeSidecarBytes(audioPath, ext string, data []byte) error {
	sidecarPath := strings.TrimSuffix(audioPath, filepath.Ext(audioPath)) + ext
	return os.WriteFile(sidecarPath, data, 0644)
}
