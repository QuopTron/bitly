package handlers

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

func registerLibraryPages(reg *rpc.Registry) {
	reg.Register("getLocalLibraryPage", func(params map[string]interface{}) (interface{}, error) {
		limit := rpc.Sn(params, "limit")
		offset := rpc.Sn(params, "offset")
		searchQuery := rpc.Sp(params, "searchQuery")
		sortMode := rpc.Sp(params, "sortMode")
		if limit <= 0 {
			limit = 50
		}
		result, err := database.GetLocalLibraryPage(limit, offset, searchQuery, sortMode)
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("getLocalLibraryCount", func(params map[string]interface{}) (interface{}, error) {
		count, err := database.GetLocalLibraryCount(rpc.Sp(params, "searchQuery"))
		if err != nil {
			return 0, err
		}
		return count, nil
	})

	reg.Register("getLocalLibraryAlbumGroups", func(params map[string]interface{}) (interface{}, error) {
		limit := rpc.Sn(params, "limit")
		offset := rpc.Sn(params, "offset")
		searchQuery := rpc.Sp(params, "searchQuery")
		if limit <= 0 {
			limit = 50
		}
		result, err := database.GetLocalLibraryAlbumGroups(limit, offset, searchQuery)
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("getLocalLibraryAlbumGroupCount", func(params map[string]interface{}) (interface{}, error) {
		count, err := database.GetLocalLibraryAlbumGroupCount(rpc.Sp(params, "searchQuery"))
		if err != nil {
			return 0, err
		}
		return count, nil
	})

	reg.Register("getLocalLibrarySingleTrackCount", func(params map[string]interface{}) (interface{}, error) {
		searchQuery := rpc.Sp(params, "search_query")
		if searchQuery == "" {
			searchQuery = rpc.Sp(params, "searchQuery")
		}
		count, err := database.GetLocalLibrarySingleTrackCount(searchQuery)
		if err != nil {
			return 0, err
		}
		return count, nil
	})
}
