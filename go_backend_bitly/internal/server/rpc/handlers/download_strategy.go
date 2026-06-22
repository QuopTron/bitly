package handlers

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/zarz/bitly/go_backend_bitly/internal/domain/track"
	downloadCore "github.com/zarz/bitly/go_backend_bitly/internal/download/core"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerDownloadStrategy(reg *rpc.Registry) {
	reg.Register("downloadByStrategy", func(params map[string]interface{}) (interface{}, error) {
		initDownloadServices()
		request := rpc.Sp(params, "request")
		if request == "" {
			return nil, fmt.Errorf("request is required")
		}
		var req downloadRequestJSON
		if err := json.Unmarshal([]byte(request), &req); err != nil {
			return nil, fmt.Errorf("invalid request JSON: %w", err)
		}
		if req.TrackTitle == "" || req.ArtistName == "" {
			return nil, fmt.Errorf("track_title and artist_name are required")
		}
		downloadReq := downloadCore.SingleDownloadRequest{
			UserID:  req.UserID,
			Quality: req.Quality,
			Type:    req.Type,
			Track: track.Track{
				ID:         req.TrackID,
				Title:      req.TrackTitle,
				DurationMs: req.DurationMs,
				ISRC:       req.ISRC,
			},
		}
		if downloadReq.Type == "" {
			downloadReq.Type = "audio"
		}
		if downloadReq.Quality == "" {
			downloadReq.Quality = "flac"
		}
		if err := globalOrchestrator.DownloadSingle(context.Background(), downloadReq); err != nil {
			return nil, fmt.Errorf("download failed: %w", err)
		}
		return "ok", nil
	})

	reg.Register("cancelDownload", func(params map[string]interface{}) (interface{}, error) {
		downloadCore.CancelDownload(rpc.Sp(params, "item_id"))
		return "ok", nil
	})
}
