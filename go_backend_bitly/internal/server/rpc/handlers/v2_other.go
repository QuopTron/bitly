package handlers

import (
	"strconv"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

func registerV2Other(reg *rpc.Registry) {
	reg.Register("getUserPremiumV2JSON", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetUserPremiumV2()
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("setUserPremiumV2JSON", func(params map[string]interface{}) (interface{}, error) {
		tier := rpc.Sp(params, "tier")
		premiumUntil := int64(rpc.Sn(params, "premium_until"))
		return "ok", database.SetUserPremiumV2(tier, premiumUntil)
	})

	reg.Register("getListeningLevelV2JSON", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetListeningLevelV2()
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("logPlayV2JSON", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.LogPlayV2(
			rpc.Sp(params, "track_id"), rpc.Sp(params, "track_name"),
			rpc.Sp(params, "artist_name"), rpc.Sp(params, "album_name"),
			rpc.Sn(params, "duration_ms"), rpc.Sn(params, "percentage"))
	})

	reg.Register("getPlayStatsV2JSON", func(params map[string]interface{}) (interface{}, error) {
		return database.GetPlayStatsV2(rpc.Sp(params, "type"), rpc.Sp(params, "item_id"))
	})

	reg.Register("getRecentPlaysV2JSON", func(params map[string]interface{}) (interface{}, error) {
		limit := rpc.Sn(params, "limit")
		if limit <= 0 {
			limit = 50
		}
		return database.GetRecentPlaysV2(limit)
	})

	reg.Register("logDownloadV2JSON", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.LogDownloadV2(
			rpc.Sp(params, "track_id"), rpc.Sp(params, "album_id"),
			rpc.Sp(params, "file_id"), rpc.Sp(params, "source"))
	})

	reg.Register("getDownloadedTracksV2JSON", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetDownloadedTracksV2()
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("getDownloadedAlbumsV2JSON", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetDownloadedAlbumsV2()
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("getArtistTopTracksV2JSON", func(params map[string]interface{}) (interface{}, error) {
		artistID := rpc.Sp(params, "artist_id")
		limit := rpc.Sn(params, "limit")
		if limit <= 0 {
			limit = 20
		}
		return database.GetArtistTopTracksV2(artistID, limit)
	})

	reg.Register("getArtistTopAlbumsV2JSON", func(params map[string]interface{}) (interface{}, error) {
		artistID := rpc.Sp(params, "artist_id")
		limit := rpc.Sn(params, "limit")
		if limit <= 0 {
			limit = 10
		}
		return database.GetArtistTopAlbumsV2(artistID, limit)
	})

	reg.Register("addSimilarArtistV2JSON", func(params map[string]interface{}) (interface{}, error) {
		artistID := rpc.Sp(params, "artist_id")
		similarArtistID := rpc.Sp(params, "similar_artist_id")
		score := 0.0
		if v, ok := params["similarity_score"]; ok {
			switch s := v.(type) {
			case float64:
				score = s
			case string:
				score, _ = strconv.ParseFloat(s, 64)
			}
		}
		return "ok", database.AddSimilarArtistV2(artistID, similarArtistID, score)
	})

	reg.Register("getSimilarArtistsV2JSON", func(params map[string]interface{}) (interface{}, error) {
		return database.GetSimilarArtistsV2(rpc.Sp(params, "artist_id"))
	})
}
