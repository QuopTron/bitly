package handlers

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

func registerV2Tracks(reg *rpc.Registry) {
	reg.Register("getTrackV2ByID", func(params map[string]interface{}) (interface{}, error) {
		return database.GetTrackV2ByID(rpc.Sp(params, "track_id"))
	})

	reg.Register("updateTrackCoverPathV2", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.UpdateTrackCoverPathV2(rpc.Sp(params, "track_id"), rpc.Sp(params, "cover_path"))
	})

	reg.Register("addLovedTrackV2JSON", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.AddLovedTrackV2(
			rpc.Sp(params, "track_id"), rpc.Sp(params, "track_name"),
			rpc.Sp(params, "artist_name"), rpc.Sp(params, "album_name"),
			rpc.Sp(params, "isrc"), rpc.Sp(params, "cover_url"),
			rpc.Sp(params, "spotify_id"), rpc.Sn(params, "duration_ms"),
			rpc.Sn(params, "track_number"), rpc.Sp(params, "cover_path"))
	})

	reg.Register("removeLovedTrackV2JSON", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.RemoveLovedTrackV2(
			rpc.Sp(params, "track_id"), rpc.Sp(params, "isrc"),
			rpc.Sp(params, "track_name"), rpc.Sp(params, "artist_name"))
	})

	reg.Register("getLovedTracksV2JSON", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetLovedTracksV2()
		if err != nil {
			return nil, err
		}
		return result, nil
	})
}
