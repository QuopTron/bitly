package handlers

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/audio/metadata"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

type reEnrichRequest struct {
	FilePath     string   `json:"file_path"`
	CoverURL     string   `json:"cover_url"`
	MaxQuality   bool     `json:"max_quality"`
	EmbedLyrics  bool     `json:"embed_lyrics"`
	SearchOnline bool     `json:"search_online"`
	TrackName    string   `json:"track_name"`
	ArtistName   string   `json:"artist_name"`
	AlbumName    string   `json:"album_name"`
	AlbumArtist  string   `json:"album_artist"`
	Date         string   `json:"date"`
	ISRC         string   `json:"isrc"`
	Genre        string   `json:"genre"`
	Label        string   `json:"label"`
	Copyright    string   `json:"copyright"`
	Composer     string   `json:"composer"`
	TrackNumber  int      `json:"track_number"`
	TotalTracks  int      `json:"total_tracks"`
	DiscNumber   int      `json:"disc_number"`
	TotalDiscs   int      `json:"total_discs"`
	SpotifyID    string   `json:"spotify_id"`
	DurationMs   int64    `json:"duration_ms"`
	UpdateFields []string `json:"update_fields,omitempty"`
}

func registerMetadataReEnrich(reg *rpc.Registry) {
	reg.Register("reEnrichFile", func(params map[string]interface{}) (interface{}, error) {
		requestJSON := rpc.Sp(params, "request_json")
		if requestJSON == "" {
			return "", fmt.Errorf("request_json is required")
		}

		var req reEnrichRequest
		if err := json.Unmarshal([]byte(requestJSON), &req); err != nil {
			return "", fmt.Errorf("failed to parse request: %w", err)
		}
		if req.FilePath == "" {
			return "", fmt.Errorf("file_path is required")
		}

		shouldUpdate := makeShouldUpdateFn(req.UpdateFields)

		coverData, coverTempPath := downloadCoverIfNeeded(req.CoverURL, req.MaxQuality, shouldUpdate)
		defer func() {
			if coverTempPath != "" {
				os.Remove(coverTempPath)
			}
		}()

		lower := strings.ToLower(req.FilePath)
		if strings.HasSuffix(lower, ".flac") {
			return reEnrichFLAC(req, coverData, shouldUpdate), nil
		}
		return reEnrichNonFLAC(req, coverTempPath, shouldUpdate), nil
	})
}

func makeShouldUpdateFn(updateFields []string) func(string) bool {
	return func(field string) bool {
		if len(updateFields) == 0 {
			return true
		}
		for _, f := range updateFields {
			if f == field {
				return true
			}
		}
		return false
	}
}

func downloadCoverIfNeeded(coverURL string, maxQuality bool, shouldUpdate func(string) bool) ([]byte, string) {
	if coverURL == "" || !shouldUpdate("cover") {
		return nil, ""
	}
	data, err := metadata.DownloadCoverToMemory(coverURL, maxQuality)
	if err != nil {
		return nil, ""
	}
	return data, ""
}
