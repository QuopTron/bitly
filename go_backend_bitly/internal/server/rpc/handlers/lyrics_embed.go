package handlers

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/lyrics"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerLyricsEmbed(reg *rpc.Registry) {
	reg.Register("embedLyricsToFile", func(params map[string]interface{}) (interface{}, error) {
		audioFilePath := rpc.Sp(params, "audio_file_path")
		trackName := rpc.Sp(params, "track_name")
		artistName := rpc.Sp(params, "artist_name")
		durationMs := int64(rpc.Sn(params, "duration_ms"))

		if audioFilePath == "" || trackName == "" || artistName == "" {
			return map[string]interface{}{
				"success": false, "message": "audio_file_path, track_name, and artist_name are required",
			}, nil
		}

		client := lyrics.NewLyricsClient()
		durationSec := float64(durationMs) / 1000.0
		result, err := client.FetchLyricsAllSources("", trackName, artistName, durationSec)
		if err != nil || result == nil {
			return map[string]interface{}{"success": true, "message": "no lyrics found"}, nil
		}

		if !result.Instrumental {
			lrcContent := lyrics.ConvertToLRCWithMetadata(result, trackName, artistName)
			path, err := lyrics.SaveLRCFile(audioFilePath, lrcContent)
			if err != nil {
				return map[string]interface{}{"success": false, "message": err.Error()}, nil
			}
			return map[string]interface{}{"success": true, "message": "lyrics saved", "path": path}, nil
		}

		return map[string]interface{}{"success": true, "message": "instrumental track, no lyrics saved"}, nil
	})

	reg.Register("saveLRCFile", func(params map[string]interface{}) (interface{}, error) {
		audioFilePath := rpc.Sp(params, "audio_file_path")
		lrcContent := rpc.Sp(params, "lyrics")
		path, err := lyrics.SaveLRCFile(audioFilePath, lrcContent)
		if err != nil {
			return nil, err
		}
		return map[string]interface{}{"success": true, "path": path}, nil
	})
}
