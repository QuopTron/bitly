package handlers

import (
	"encoding/json"
	"fmt"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

// RegisterDuplicateHandlers registers duplicate-detection RPC methods.
func RegisterDuplicateHandlers(reg *rpc.Registry) {
	reg.Register("checkDuplicate", func(params map[string]interface{}) (interface{}, error) {
		outputDir := rpc.Sp(params, "output_dir")
		isrc := rpc.Sp(params, "isrc")
		if outputDir == "" || isrc == "" {
			result := map[string]interface{}{"exists": false, "filepath": ""}
			out, _ := json.Marshal(result)
			return string(out), nil
		}
		filePath, exists := checkISRCExists(outputDir, isrc)
		result := map[string]interface{}{
			"exists":   exists,
			"filepath": filePath,
		}
		out, _ := json.Marshal(result)
		return string(out), nil
	})

	reg.Register("checkDuplicatesBatch", func(params map[string]interface{}) (interface{}, error) {
		tracksJSON := rpc.Sp(params, "tracks_json")
		outputDir := rpc.Sp(params, "output_dir")
		if tracksJSON == "" || outputDir == "" {
			return "{}", nil
		}
		return checkFilesExistParallel(outputDir, tracksJSON)
	})

	reg.Register("preBuildDuplicateIndex", func(params map[string]interface{}) (interface{}, error) {
		outputDir := rpc.Sp(params, "output_dir")
		if outputDir == "" {
			return nil, fmt.Errorf("missing output_dir")
		}
		return preBuildISRCIndex(outputDir), nil
	})

	reg.Register("invalidateDuplicateIndex", func(params map[string]interface{}) (interface{}, error) {
		outputDir := rpc.Sp(params, "output_dir")
		if outputDir != "" {
			invalidateISRCCache(outputDir)
		}
		return "ok", nil
	})

	reg.Register("allowDownloadDir", func(params map[string]interface{}) (interface{}, error) {
		// In the new backend, download dir permissions are handled differently.
		// Accept the request without doing anything.
		return "ok", nil
	})
}

// checkISRCExists looks for an existing file with the same ISRC in a directory.
func checkISRCExists(dir, isrc string) (string, bool) {
	db, err := database.Get()
	if err != nil {
		return "", false
	}
	var filePath string
	err = db.QueryRow(
		"SELECT f.file_path FROM files f JOIN metadata m ON f.metadata_id = m.id WHERE m.isrc = ? LIMIT 1",
		isrc).Scan(&filePath)
	if err != nil {
		return "", false
	}
	return filePath, true
}

// checkFilesExistParallel checks multiple tracks for duplicates in batch.
func checkFilesExistParallel(dir, tracksJSON string) (string, error) {
	var tracks []struct {
		ISRC string `json:"isrc"`
	}
	if err := json.Unmarshal([]byte(tracksJSON), &tracks); err != nil {
		return "{}", nil
	}
	result := make(map[string]bool)
	for _, t := range tracks {
		if t.ISRC != "" {
			_, exists := checkISRCExists(dir, t.ISRC)
			result[t.ISRC] = exists
		}
	}
	if len(result) == 0 {
		// Return empty result
	}
	out, _ := json.Marshal(result)
	return string(out), nil
}

func preBuildISRCIndex(dir string) error {
	// In the old backend this built a memory index for faster lookups.
	// The new backend queries SQLite directly which is already fast.
	return nil
}

func invalidateISRCCache(dir string) {
	// Clear any cached index in memory.
	// No-op in new backend since we query DB directly.
}
