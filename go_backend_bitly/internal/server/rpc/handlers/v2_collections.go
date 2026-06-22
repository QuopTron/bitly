package handlers

import (
	"encoding/json"
	"fmt"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

func registerV2Collections(reg *rpc.Registry) {
	reg.Register("createCollectionV2JSON", func(params map[string]interface{}) (interface{}, error) {
		name := rpc.Sp(params, "name")
		collectionType := rpc.Sp(params, "type")
		coverPath := rpc.Sp(params, "cover_path")
		result, err := database.CreateCollectionV2(name, collectionType, coverPath)
		if err != nil {
			return "", err
		}
		return result, nil
	})

	reg.Register("updateCollectionV2JSON", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.UpdateCollectionV2(
			rpc.Sp(params, "id"), rpc.Sp(params, "name"), rpc.Sp(params, "cover_path"))
	})

	reg.Register("addCollectionTrackV2JSON", func(params map[string]interface{}) (interface{}, error) {
		collectionID := rpc.Sp(params, "collection_id")
		trackID := rpc.Sp(params, "track_id")
		if trackID == "" {
			trackID = rpc.Sp(params, "item_id")
		}
		return "ok", database.AddCollectionTrackV2(collectionID, trackID)
	})

	reg.Register("removeCollectionTrackV2", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.RemoveCollectionTrackV2(
			rpc.Sp(params, "collection_id"), rpc.Sp(params, "item_id"))
	})

	reg.Register("getCollectionTracksV2JSON", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetCollectionTracksV2(rpc.Sp(params, "collection_id"))
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("getFavoritePlaylistsV2JSON", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetFavoritePlaylistsV2()
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("reorderCollectionItemsV2JSON", func(params map[string]interface{}) (interface{}, error) {
		collectionID := rpc.Sp(params, "collection_id")
		itemIDsRaw := params["item_ids"]
		var itemIDs []string
		switch v := itemIDsRaw.(type) {
		case string:
			if err := json.Unmarshal([]byte(v), &itemIDs); err != nil {
				return nil, fmt.Errorf("invalid item_ids JSON: %w", err)
			}
		case []interface{}:
			for _, id := range v {
				if s, ok := id.(string); ok {
					itemIDs = append(itemIDs, s)
				}
			}
		}
		if itemIDs == nil {
			itemIDs = []string{}
		}
		return "ok", database.ReorderCollectionItemsV2(collectionID, itemIDs)
	})

	reg.Register("deleteCollectionV2", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.DeleteCollectionV2(rpc.Sp(params, "collection_id"))
	})
}
