package handlers

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

func registerDownloadMisc(reg *rpc.Registry) {
	reg.Register("existingDownloadTrackKeys", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.ExistingDownloadTrackKeys(rpc.Sp(params, "request"))
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("getDownloadAlbumTracks", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetDownloadAlbumTracks(rpc.Sp(params, "album"), rpc.Sp(params, "artist"))
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("getDownloadArtistTracks", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetDownloadArtistTracks(rpc.Sp(params, "artist"))
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("findExistingDownloadEntry", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.FindExistingDownloadEntry(
			rpc.Sp(params, "spotify_id"), rpc.Sp(params, "isrc"),
			rpc.Sp(params, "track_name"), rpc.Sp(params, "artist_name"))
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("getQueueCounts", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetQueueCounts(rpc.Sp(params, "searchQuery"))
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("saveDownloadQueue", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.SaveDownloadQueue(rpc.Sp(params, "items"))
	})

	reg.Register("loadDownloadQueue", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.LoadDownloadQueue()
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("getPendingDownloadQueueRows", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetPendingDownloadQueueRows()
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("replacePendingDownloadQueueRows", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.ReplacePendingDownloadQueueRows(rpc.Sp(params, "rows"))
	})

	reg.Register("upsertRecentAccessRow", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.UpsertRecentAccessRow(rpc.Sp(params, "key"), rpc.Sp(params, "json"), rpc.Sp(params, "accessed_at"))
	})

	reg.Register("getRecentAccessRows", func(params map[string]interface{}) (interface{}, error) {
		limit := rpc.Sn(params, "limit")
		if limit <= 0 {
			limit = 30
		}
		result, err := database.GetRecentAccessRows(limit)
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("deleteRecentAccessRow", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.DeleteRecentAccessRow(rpc.Sp(params, "key"))
	})

	reg.Register("clearRecentAccessRows", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.ClearRecentAccessRows()
	})

	registerDownloadMiscExtra(reg)
}
