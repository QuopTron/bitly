package handlers

import (
	"encoding/json"
	"fmt"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

func registerDownloadHistory(reg *rpc.Registry) {
	reg.Register("upsertDownloadEntry", func(params map[string]interface{}) (interface{}, error) {
		request := rpc.Sp(params, "request")
		if request == "" {
			return nil, fmt.Errorf("request is required")
		}
		return "ok", database.UpsertDownloadEntryJSON(request)
	})

	reg.Register("upsertDownloadEntriesBatch", func(params map[string]interface{}) (interface{}, error) {
		request := rpc.Sp(params, "request")
		if request == "" {
			return nil, fmt.Errorf("request is required")
		}
		var entries []database.DownloadHistoryEntry
		if err := json.Unmarshal([]byte(request), &entries); err != nil {
			return nil, fmt.Errorf("invalid batch JSON: %w", err)
		}
		for _, entry := range entries {
			if err := database.UpsertDownloadEntry(entry); err != nil {
				return nil, fmt.Errorf("batch upsert failed: %w", err)
			}
		}
		return "ok", nil
	})

	reg.Register("deleteDownloadEntriesByIDs", func(params map[string]interface{}) (interface{}, error) {
		request := rpc.Sp(params, "request")
		return "ok", database.DeleteDownloadEntriesByIDsJSON(request)
	})

	reg.Register("deleteDownloadEntriesByPaths", func(params map[string]interface{}) (interface{}, error) {
		request := rpc.Sp(params, "request")
		var paths []string
		if err := json.Unmarshal([]byte(request), &paths); err != nil {
			return nil, fmt.Errorf("invalid paths JSON: %w", err)
		}
		return "ok", database.DeleteDownloadEntriesByPaths(paths)
	})

	reg.Register("deleteDownloadEntriesByTrackMatch", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.DeleteDownloadEntriesByTrackMatch(
			rpc.Sp(params, "track_name"), rpc.Sp(params, "artist_name"))
	})

	reg.Register("getDownloadHistory", func(params map[string]interface{}) (interface{}, error) {
		limit := rpc.Sn(params, "limit")
		offset := rpc.Sn(params, "offset")
		if limit <= 0 {
			limit = 50
		}
		result, err := database.GetDownloadHistory(limit, offset)
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("clearDownloadHistory", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.ClearDownloadHistory()
	})

	reg.Register("getDownloadHistoryCount", func(params map[string]interface{}) (interface{}, error) {
		return database.GetDownloadHistoryCount()
	})

	reg.Register("getDownloadHistoryGroupedCounts", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetDownloadHistoryGroupedCounts()
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	registerDownloadHistoryExtra(reg)
}
