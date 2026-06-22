package handlers

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

func registerV2Artists(reg *rpc.Registry) {
	reg.Register("getAllArtistsV2JSON", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetAllArtistsV2()
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("getFavoriteArtistsV2JSON", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetFavoriteArtistsV2()
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("addFavoriteArtistV2JSON", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.AddFavoriteArtistV2(
			rpc.Sp(params, "artist_id"), rpc.Sp(params, "name"),
			rpc.Sp(params, "image_url"), rpc.Sp(params, "provider"),
			rpc.Sp(params, "added_at"))
	})

	reg.Register("removeFavoriteArtistV2JSON", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.RemoveFavoriteArtistV2(rpc.Sp(params, "artist_id"))
	})

	reg.Register("updateArtistImageV2JSON", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.UpdateArtistImageV2(
			rpc.Sp(params, "artist_id"), rpc.Sp(params, "image_url"), rpc.Sp(params, "file_path"))
	})
}
