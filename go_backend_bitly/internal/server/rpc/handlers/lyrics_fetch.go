package handlers

import (
	"fmt"
	"os"
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/audio/metadata"
	"github.com/zarz/bitly/go_backend_bitly/internal/lyrics"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerLyricsFetch(reg *rpc.Registry) {
	reg.Register("fetchLyrics", func(params map[string]interface{}) (interface{}, error) {
		spotifyID := rpc.Sp(params, "spotify_id")
		trackName := rpc.Sp(params, "track_name")
		artistName := rpc.Sp(params, "artist_name")
		durationMs := int64(rpc.Sn(params, "duration_ms"))

		client := lyrics.NewLyricsClient()
		durationSec := float64(durationMs) / 1000.0
		result, err := client.FetchLyricsAllSources(spotifyID, trackName, artistName, durationSec)
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("getLyricsLRC", func(params map[string]interface{}) (interface{}, error) {
		trackName := rpc.Sp(params, "track_name")
		artistName := rpc.Sp(params, "artist_name")
		durationMs := int64(rpc.Sn(params, "duration_ms"))

		client := lyrics.NewLyricsClient()
		durationSec := float64(durationMs) / 1000.0
		result, err := client.FetchLyricsAllSources("", trackName, artistName, durationSec)
		if err != nil {
			return "", nil
		}
		if result.Instrumental {
			return "[instrumental:true]", nil
		}
		return lyrics.ConvertToLRCWithMetadata(result, trackName, artistName), nil
	})

	reg.Register("fetchAndSaveLyrics", func(params map[string]interface{}) (interface{}, error) {
		trackName := rpc.Sp(params, "track_name")
		artistName := rpc.Sp(params, "artist_name")
		spotifyID := rpc.Sp(params, "spotify_id")
		durationMs := int64(rpc.Sn(params, "duration_ms"))
		outputPath := rpc.Sp(params, "output_path")
		audioFilePath := rpc.Sp(params, "audio_file_path")

		if outputPath == "" {
			return nil, fmt.Errorf("output_path is required")
		}

		// If audio file has embedded lyrics or a sidecar .lrc, use those first
		if audioFilePath != "" {
			existing, err := metadata.ExtractLyrics(audioFilePath)
			if err == nil && strings.TrimSpace(existing) != "" {
				if err := os.WriteFile(outputPath, []byte(existing), 0644); err != nil {
					return nil, fmt.Errorf("failed to write LRC file: %w", err)
				}
				return map[string]interface{}{"success": true, "message": "Lyrics saved from embedded/sidecar file"}, nil
			}
		}

		client := lyrics.NewLyricsClient()
		durationSec := float64(durationMs) / 1000.0
		result, err := client.FetchLyricsAllSources(spotifyID, trackName, artistName, durationSec)
		if err != nil {
			return nil, err
		}

		if result.Instrumental {
			return nil, fmt.Errorf("track is instrumental, no lyrics available")
		}

		lrcContent := lyrics.ConvertToLRCWithMetadata(result, trackName, artistName)
		if lrcContent == "" {
			return nil, fmt.Errorf("failed to generate LRC content")
		}

		if err := os.WriteFile(outputPath, []byte(lrcContent), 0644); err != nil {
			return nil, fmt.Errorf("failed to write LRC file: %w", err)
		}

		return map[string]interface{}{"success": true, "message": "Lyrics saved to file"}, nil
	})

	reg.Register("getLyricsLRCWithSource", func(params map[string]interface{}) (interface{}, error) {
		trackName := rpc.Sp(params, "track_name")
		artistName := rpc.Sp(params, "artist_name")
		durationMs := int64(rpc.Sn(params, "duration_ms"))

		client := lyrics.NewLyricsClient()
		durationSec := float64(durationMs) / 1000.0
		result, err := client.FetchLyricsAllSources("", trackName, artistName, durationSec)
		if err != nil || result == nil {
			return map[string]interface{}{
				"lyrics": "", "source": "", "sync_type": "", "instrumental": false,
			}, nil
		}
		lrc := ""
		if !result.Instrumental {
			lrc = lyrics.ConvertToLRCWithMetadata(result, trackName, artistName)
		}
		return map[string]interface{}{
			"lyrics": lrc, "source": result.Provider,
			"sync_type": result.SyncType, "instrumental": result.Instrumental,
		}, nil
	})
}
