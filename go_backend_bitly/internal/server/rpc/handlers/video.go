package handlers

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/providers/youtube"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/cache"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

// RegisterVideoHandlers registers video-related RPC methods.
// Uses youtube.GetClient() for real YouTube search and download.
func RegisterVideoHandlers(reg *rpc.Registry) {
	getVideoURL := func() *cache.VideoURLCache {
		db, err := database.Get()
		if err != nil {
			return nil
		}
		return cache.NewVideoURLCache(db)
	}

	reg.Register("clearVideoUrlCache", func(params map[string]interface{}) (interface{}, error) {
		vc := getVideoURL()
		if vc == nil {
			return "ok", nil
		}
		return "ok", vc.Clear()
	})

	reg.Register("getVideoUrlCacheCount", func(params map[string]interface{}) (interface{}, error) {
		vc := getVideoURL()
		if vc == nil {
			return 0, nil
		}
		count, err := vc.Count()
		if err != nil {
			return 0, err
		}
		return count, nil
	})


	reg.Register("searchYouTubeVideo", func(params map[string]interface{}) (interface{}, error) {
		client := youtube.GetClient()
		trackName := rpc.Sp(params, "track_name")
		artistName := rpc.Sp(params, "artist_name")
		url, err := client.SearchYouTubeVideo(trackName, artistName)
		if err != nil {
			return "", err
		}
		return url, nil
	})

	reg.Register("downloadYouTubeVideo", func(params map[string]interface{}) (interface{}, error) {
		client := youtube.GetClient()
		trackName := rpc.Sp(params, "track_name")
		artistName := rpc.Sp(params, "artist_name")
		outputPath := rpc.Sp(params, "output_path")
		result, err := client.DownloadYouTubeVideo(trackName, artistName, outputPath)
		if err != nil {
			return "", err
		}
		return result, nil
	})

	reg.Register("ensureYtDlp", func(params map[string]interface{}) (interface{}, error) {
		err := youtube.EnsureYtDlp()
		if err != nil {
			return "", err
		}
		return "ok", nil
	})

	reg.Register("getYtDlpPath", func(params map[string]interface{}) (interface{}, error) {
		return youtube.YtDlpPath(), nil
	})

	reg.Register("setYtDlpPath", func(params map[string]interface{}) (interface{}, error) {
		path := rpc.Sp(params, "path")
		youtube.SetCustomYtDlpPath(path)
		return "ok", nil
	})
}
