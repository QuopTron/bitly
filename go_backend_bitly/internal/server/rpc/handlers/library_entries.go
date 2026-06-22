package handlers

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

func registerLibraryEntries(reg *rpc.Registry) {
	reg.Register("getLocalLibraryEntryByID", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetLocalLibraryEntryByID(rpc.Sp(params, "id"))
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("getLocalLibraryEntryByIsrc", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetLocalLibraryEntryByIsrc(rpc.Sp(params, "isrc"))
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("findLocalLibraryEntryByTrackAndArtist", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.FindLocalLibraryEntryByTrackAndArtist(
			rpc.Sp(params, "track_name"), rpc.Sp(params, "artist_name"))
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("getLocalLibraryCoverPaths", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetLocalLibraryCoverPaths()
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("getLocalLibraryEntriesWithPathsPage", func(params map[string]interface{}) (interface{}, error) {
		limit := rpc.Sn(params, "limit")
		offset := rpc.Sn(params, "offset")
		if limit <= 0 {
			limit = 100
		}
		result, err := database.GetLocalLibraryEntriesWithPathsPage(limit, offset)
		if err != nil {
			return nil, err
		}
		return result, nil
	})
}
