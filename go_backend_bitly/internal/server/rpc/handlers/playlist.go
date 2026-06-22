package handlers

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend_bitly/internal/playlist"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

// RegisterPlaylistHandlers registers RPC methods for playlist file generation.
func RegisterPlaylistHandlers(reg *rpc.Registry) {
	reg.Register("generateM3U", func(params map[string]interface{}) (interface{}, error) {
		cfg, err := parsePlaylistConfig(params)
		if err != nil {
			return "", err
		}
		return playlist.GenerateM3U(cfg)
	})

	reg.Register("generateM3U8", func(params map[string]interface{}) (interface{}, error) {
		cfg, err := parsePlaylistConfig(params)
		if err != nil {
			return "", err
		}
		return playlist.GenerateM3U8(cfg)
	})

	reg.Register("generateCUE", func(params map[string]interface{}) (interface{}, error) {
		cfg, err := parsePlaylistConfig(params)
		if err != nil {
			return "", err
		}
		return playlist.GenerateCUE(cfg)
	})

	reg.Register("generateNFO", func(params map[string]interface{}) (interface{}, error) {
		cfg, err := parsePlaylistConfig(params)
		if err != nil {
			return "", err
		}
		return playlist.GenerateNFO(cfg)
	})

	reg.Register("generateBulkPlaylistFiles", func(params map[string]interface{}) (interface{}, error) {
		cfg, err := parsePlaylistConfig(params)
		if err != nil {
			return "", err
		}
		result := playlist.GenerateBulkPlaylistFiles(cfg)
		out, _ := json.Marshal(result)
		return string(out), nil
	})
}

func parsePlaylistConfig(params map[string]interface{}) (playlist.Config, error) {
	cfg := playlist.Config{
		Name:      rpc.Sp(params, "name"),
		Artist:    rpc.Sp(params, "artist"),
		Year:      rpc.Sp(params, "year"),
		Genre:     rpc.Sp(params, "genre"),
		OutputDir: rpc.Sp(params, "output_dir"),
	}

	tracksRaw, _ := params["tracks"].([]interface{})
	for _, t := range tracksRaw {
		trackMap, ok := t.(map[string]interface{})
		if !ok {
			continue
		}
		cfg.Tracks = append(cfg.Tracks, playlist.Track{
			Title:    rpc.Sp(trackMap, "title"),
			Artist:   rpc.Sp(trackMap, "artist"),
			Album:    rpc.Sp(trackMap, "album"),
			Duration: int(rpc.Sn(trackMap, "duration_ms")),
			FilePath: rpc.Sp(trackMap, "file_path"),
			TrackNum: int(rpc.Sn(trackMap, "track_number")),
			DiscNum:  int(rpc.Sn(trackMap, "disc_number")),
			ISRC:     rpc.Sp(trackMap, "isrc"),
		})
	}

	if cfg.OutputDir == "" {
		return cfg, nil
	}
	return cfg, nil
}
