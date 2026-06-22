package handlers

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

func registerV2Albums(reg *rpc.Registry) {
	reg.Register("getAllAlbumsV2JSON", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetAllAlbumsV2()
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("getFavoriteAlbumsV2JSON", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetFavoriteAlbumsV2()
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("addFavoriteAlbumV2JSON", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.AddFavoriteAlbumV2(
			rpc.Sp(params, "album_id"), rpc.Sp(params, "name"),
			rpc.Sp(params, "artist_id"), rpc.Sp(params, "artist_name"),
			rpc.Sp(params, "cover_url"), rpc.Sp(params, "provider"))
	})

	reg.Register("removeFavoriteAlbumV2JSON", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.RemoveFavoriteAlbumV2(rpc.Sp(params, "album_id"))
	})
}
