package handlers

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

func registerV2Wishlist(reg *rpc.Registry) {
	reg.Register("addWishlistTrackV2JSON", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.AddWishlistTrackV2(
			rpc.Sp(params, "track_id"), rpc.Sp(params, "track_name"),
			rpc.Sp(params, "artist_name"), rpc.Sp(params, "album_name"),
			rpc.Sp(params, "isrc"), rpc.Sp(params, "cover_url"),
			rpc.Sn(params, "duration_ms"))
	})

	reg.Register("removeWishlistTrackV2JSON", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.RemoveWishlistTrackV2(
			rpc.Sp(params, "track_id"), rpc.Sp(params, "isrc"),
			rpc.Sp(params, "track_name"), rpc.Sp(params, "artist_name"))
	})

	reg.Register("getWishlistTracksV2JSON", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetWishlistTracksV2()
		if err != nil {
			return nil, err
		}
		return result, nil
	})
}
