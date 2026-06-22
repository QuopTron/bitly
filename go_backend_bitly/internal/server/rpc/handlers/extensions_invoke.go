package handlers

import (
	"encoding/json"
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/api"
)

func registerExtensionInvoke(reg *rpc.Registry) {
	reg.Register("invokeExtensionAction", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		extensionID := rpc.Sp(params, "extension_id")
		action := rpc.Sp(params, "action")
		result, err := extClient.InvokeAction(extensionID, action, params)
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("searchTracksWithMetadataProviders", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		query := rpc.Sp(params, "query")
		limit := rpc.Sn(params, "limit")
		if limit <= 0 || limit > 50 {
			limit = 20
		}
		if query == "" {
			return "[]", nil
		}
		var allTracks []api.SearchResult
		seen := map[string]struct{}{}
		for _, ext := range extManager.ListExtensions() {
			if ext == nil || !ext.Enabled || ext.Error != "" {
				continue
			}
			extType := ext.Type
			if !strings.Contains(extType, "metadata_provider") &&
				!strings.Contains(extType, "download_provider") {
				continue
			}
			if !extRuntime.IsLoaded(ext.ID) {
				continue
			}
			tracks, err := extClient.SearchTracks(ext.ID, query, limit)
			if err != nil || len(tracks) == 0 {
				continue
			}
			for _, t := range tracks {
				key := t.ID + "|" + t.ISRC
				if key == "|" {
					key = t.Name + "|" + t.Artists
				}
				if _, dup := seen[key]; dup {
					continue
				}
				seen[key] = struct{}{}
				allTracks = append(allTracks, t)
				if len(allTracks) >= limit {
					break
				}
			}
			if len(allTracks) >= limit {
				break
			}
		}
		b, _ := json.Marshal(allTracks)
		return string(b), nil
	})

	registerExtensionInvokeExtra(reg)
}
