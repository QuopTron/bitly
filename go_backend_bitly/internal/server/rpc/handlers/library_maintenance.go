package handlers

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

func registerLibraryMaintenance(reg *rpc.Registry) {
	reg.Register("updateLocalLibraryFileModTimes", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.UpdateLocalLibraryFileModTimes(rpc.Sp(params, "entries"))
	})

	reg.Register("updateLocalLibraryAudioMetadata", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.UpdateLocalLibraryAudioMetadata(rpc.Sp(params, "request"))
	})

	reg.Register("getLocalLibraryArtistTracks", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetLocalLibraryArtistTracks(rpc.Sp(params, "artist"))
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("getLocalLibraryAlbumTracks", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetLocalLibraryAlbumTracks(rpc.Sp(params, "album"), rpc.Sp(params, "artist"))
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("upsertLocalLibraryEntry", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.UpsertLocalLibraryEntryJSON(rpc.Sp(params, "request"))
	})

	reg.Register("upsertLocalLibraryEntriesBatch", func(params map[string]interface{}) (interface{}, error) {
		request := rpc.Sp(params, "request")
		var entries []database.DownloadHistoryEntry
		if err := json.Unmarshal([]byte(request), &entries); err != nil {
			return "", err
		}
		for _, entry := range entries {
			if err := database.UpsertLocalLibraryEntry(entry); err != nil {
				return "", err
			}
		}
		return "ok", nil
	})

	reg.Register("clearLocalLibrary", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.ClearLocalLibrary()
	})

	reg.Register("deleteLocalLibraryEntriesByPaths", func(params map[string]interface{}) (interface{}, error) {
		requestJSON := rpc.Sp(params, "request")
		var paths []string
		if err := json.Unmarshal([]byte(requestJSON), &paths); err != nil {
			return "", err
		}
		return "ok", database.DeleteLocalLibraryEntriesByPaths(paths)
	})

	reg.Register("deleteLocalLibraryEntryByID", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.DeleteLocalLibraryEntryByID(rpc.Sp(params, "id"))
	})
}
