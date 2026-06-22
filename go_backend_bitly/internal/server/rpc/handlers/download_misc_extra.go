package handlers

import (
	"encoding/json"
	"fmt"
	"strconv"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
	"github.com/zarz/bitly/go_backend_bitly/internal/utils"
)

func registerDownloadMiscExtra(reg *rpc.Registry) {
	reg.Register("getHiddenRecentDownloadIds", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetHiddenRecentDownloadIds()
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("addHiddenRecentDownloadId", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.AddHiddenRecentDownloadId(rpc.Sp(params, "download_id"))
	})

	reg.Register("clearHiddenRecentDownloadIds", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.ClearHiddenRecentDownloadIds()
	})

	reg.Register("saveAppSettings", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.SaveAppSettings(rpc.Sp(params, "value"))
	})

	reg.Register("loadAppSettings", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.LoadAppSettings()
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("getTranslationLanguageJSON", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.LoadTranslationLanguage()
		if err != nil {
			return nil, err
		}
		if result == "" {
			return "es", nil
		}
		return result, nil
	})

	reg.Register("setTranslationLanguageJSON", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.SaveTranslationLanguage(rpc.Sp(params, "language"))
	})

	reg.Register("getLogs", func(params map[string]interface{}) (interface{}, error) {
		return utils.GetLogBuffer().GetAll(), nil
	})

	reg.Register("getLogsSince", func(params map[string]interface{}) (interface{}, error) {
		sinceSeq := int(rpc.Sn(params, "since_seq"))
		entries, nextIndex := utils.GetLogBuffer().GetSince(sinceSeq)
		logsJSON, _ := json.Marshal(entries)
		return fmt.Sprintf(`{"logs":%s,"next_index":%d}`, string(logsJSON), nextIndex), nil
	})

	reg.Register("getLogCount", func(params map[string]interface{}) (interface{}, error) {
		return strconv.Itoa(utils.GetLogBuffer().Count()), nil
	})

	reg.Register("setLoggingEnabled", func(params map[string]interface{}) (interface{}, error) {
		utils.GetLogBuffer().SetLoggingEnabled(rpc.Sb(params, "enabled"))
		return "ok", nil
	})

	reg.Register("clearLogs", func(params map[string]interface{}) (interface{}, error) {
		utils.GetLogBuffer().Clear()
		return "ok", nil
	})

	reg.Register("cleanupLocalLibraryMissingFiles", func(params map[string]interface{}) (interface{}, error) {
		pathsJSON := rpc.Sp(params, "paths_json")
		count, err := database.CleanupLocalLibraryMissingFiles(pathsJSON)
		if err != nil {
			return nil, err
		}
		return strconv.Itoa(count), nil
	})

	reg.Register("replaceLocalLibraryConvertedItem", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.ReplaceLocalLibraryConvertedItem(rpc.Sp(params, "request_json"))
	})

	reg.Register("upsertLocalLibraryEntry", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.UpsertLocalLibraryEntryJSON(rpc.Sp(params, "request"))
	})

	reg.Register("upsertLocalLibraryEntriesBatch", func(params map[string]interface{}) (interface{}, error) {
		request := rpc.Sp(params, "request")
		var entries []database.DownloadHistoryEntry
		if err := json.Unmarshal([]byte(request), &entries); err != nil {
			return nil, fmt.Errorf("invalid batch JSON: %w", err)
		}
		for _, entry := range entries {
			if err := database.UpsertLocalLibraryEntry(entry); err != nil {
				return nil, fmt.Errorf("batch upsert failed: %w", err)
			}
		}
		return "ok", nil
	})

	reg.Register("clearLocalLibrary", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.ClearLocalLibrary()
	})

	reg.Register("deleteLocalLibraryEntriesByPaths", func(params map[string]interface{}) (interface{}, error) {
		request := rpc.Sp(params, "request")
		var paths []string
		if err := json.Unmarshal([]byte(request), &paths); err != nil {
			return nil, fmt.Errorf("invalid paths JSON: %w", err)
		}
		return "ok", database.DeleteLocalLibraryEntriesByPaths(paths)
	})

	reg.Register("deleteLocalLibraryEntryByID", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.DeleteLocalLibraryEntryByID(rpc.Sp(params, "id"))
	})

	reg.Register("resetDatabase", func(params map[string]interface{}) (interface{}, error) {
		return "ok", nil
	})
}
