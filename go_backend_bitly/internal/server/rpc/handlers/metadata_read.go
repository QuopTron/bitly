package handlers

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/audio/metadata"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerMetadataRead(reg *rpc.Registry) {
	reg.Register("readFileMetadata", func(params map[string]interface{}) (interface{}, error) {
		filePath := rpc.Sp(params, "file_path")
		if filePath == "" {
			return "", fmt.Errorf("file_path is required")
		}

		lower := strings.ToLower(filePath)
		result := map[string]interface{}{
			"title": "", "artist": "", "album": "", "album_artist": "",
			"date": "", "track_number": 0, "total_tracks": 0, "disc_number": 0,
			"total_discs": 0, "isrc": "", "lyrics": "", "genre": "", "label": "",
			"copyright": "", "composer": "", "comment": "", "duration": 0,
		}

		isApeFile := strings.HasSuffix(lower, ".ape") || strings.HasSuffix(lower, ".wv") || strings.HasSuffix(lower, ".mpc")

		if isApeFile {
			if apeResult := readMetadataAPE(filePath); apeResult != nil {
				for k, v := range apeResult {
					result[k] = v
				}
			}
		} else {
			if genericResult := readMetadataGeneric(filePath); genericResult != nil {
				for k, v := range genericResult {
					result[k] = v
				}
			} else {
				readMetadataFLACFallback(filePath, result)
			}
		}

		if !isApeFile {
			quality, qErr := metadata.GetAudioQualityFromFile(filePath)
			if qErr == nil {
				result["bit_depth"] = quality.BitDepth
				result["sample_rate"] = quality.SampleRate
				if quality.SampleRate > 0 && result["duration"].(int) == 0 {
					result["duration"] = quality.Duration
				}
			}
		}

		jsonBytes, err := json.Marshal(result)
		if err != nil {
			return "", err
		}
		return string(jsonBytes), nil
	})

	reg.Register("readAudioMetadata", func(params map[string]interface{}) (interface{}, error) {
		// Alias for readFileMetadata — legacy compatibility
		filePath := rpc.Sp(params, "file_path")
		if filePath == "" {
			return "", fmt.Errorf("file_path is required")
		}

		lower := strings.ToLower(filePath)
		result := map[string]interface{}{
			"title": "", "artist": "", "album": "", "album_artist": "",
			"date": "", "track_number": 0, "total_tracks": 0, "disc_number": 0,
			"total_discs": 0, "isrc": "", "lyrics": "", "genre": "", "label": "",
			"copyright": "", "composer": "", "comment": "", "duration": 0,
		}

		isApeFile := strings.HasSuffix(lower, ".ape") || strings.HasSuffix(lower, ".wv") || strings.HasSuffix(lower, ".mpc")

		if isApeFile {
			if apeResult := readMetadataAPE(filePath); apeResult != nil {
				for k, v := range apeResult {
					result[k] = v
				}
			}
		} else {
			if genericResult := readMetadataGeneric(filePath); genericResult != nil {
				for k, v := range genericResult {
					result[k] = v
				}
			} else {
				readMetadataFLACFallback(filePath, result)
			}
		}

		if !isApeFile {
			quality, qErr := metadata.GetAudioQualityFromFile(filePath)
			if qErr == nil {
				result["bit_depth"] = quality.BitDepth
				result["sample_rate"] = quality.SampleRate
				if quality.SampleRate > 0 && result["duration"].(int) == 0 {
					result["duration"] = quality.Duration
				}
			}
		}

		jsonBytes, err := json.Marshal(result)
		if err != nil {
			return "", err
		}
		return string(jsonBytes), nil
	})
}
