package handlers

import (
	"fmt"
	"os"

	"github.com/zarz/bitly/go_backend_bitly/internal/audio/metadata"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerMetadataCover(reg *rpc.Registry) {
	reg.Register("downloadCoverToFile", func(params map[string]interface{}) (interface{}, error) {
		coverURL := rpc.Sp(params, "cover_url")
		outputPath := rpc.Sp(params, "output_path")
		maxQuality := false
		if v, ok := params["max_quality"]; ok {
			maxQuality, _ = v.(bool)
		}
		if coverURL == "" {
			return "", fmt.Errorf("no cover URL provided")
		}
		data, err := metadata.DownloadCoverToMemory(coverURL, maxQuality)
		if err != nil {
			return "", fmt.Errorf("failed to download cover: %w", err)
		}
		if err := os.WriteFile(outputPath, data, 0644); err != nil {
			return "", fmt.Errorf("failed to write cover file: %w", err)
		}
		return "ok", nil
	})

	reg.Register("extractCoverToFile", func(params map[string]interface{}) (interface{}, error) {
		audioPath := rpc.Sp(params, "audio_path")
		outputPath := rpc.Sp(params, "output_path")
		if audioPath == "" || outputPath == "" {
			return "", fmt.Errorf("audio_path and output_path are required")
		}
		coverData, _, err := metadata.ExtractCoverFromFile(audioPath)
		if err != nil {
			return "", fmt.Errorf("failed to extract cover: %w", err)
		}
		if err := os.WriteFile(outputPath, coverData, 0644); err != nil {
			return "", fmt.Errorf("failed to write cover file: %w", err)
		}
		return "ok", nil
	})
}
