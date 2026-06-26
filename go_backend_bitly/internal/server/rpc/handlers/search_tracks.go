package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/search"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerSearchTracks(reg *rpc.Registry) {
	reg.Register("searchTracks", func(params map[string]interface{}) (interface{}, error) {
		fmt.Printf("[SEARCH-RPC] searchTracks called with query=%q\n", rpc.Sp(params, "query"))
		initSearchService()
		query := rpc.Sp(params, "query")
		if query == "" {
			return []search.UnifiedResult{}, nil
		}
		limit := rpc.Sn(params, "limit")
		if limit <= 0 || limit > 50 {
			limit = 20
		}
		modeStr := rpc.Sp(params, "mode")
		mode := search.SearchModeUnified
		if modeStr == "by_source" {
			mode = search.SearchModeBySource
		} else if modeStr == "single" {
			mode = search.SearchModeSingle
		}
		source := rpc.Sp(params, "source")
		result, err := globalSearchService.Search(context.Background(), search.SearchRequest{
			Query: query, Type: "track", Mode: mode, Source: source, Limit: limit,
		})
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("searchTracksJSON", func(params map[string]interface{}) (interface{}, error) {
		initSearchService()
		query := rpc.Sp(params, "query")
		if query == "" {
			return "[]", nil
		}
		limit := rpc.Sn(params, "limit")
		if limit <= 0 || limit > 50 {
			limit = 20
		}
		result, err := globalSearchService.Search(context.Background(), search.SearchRequest{
			Query: query, Type: "track", Mode: search.SearchModeUnified, Limit: limit,
		})
		if err != nil {
			return "[]", nil
		}
		b, _ := json.Marshal(result.Unified)
		return string(b), nil
	})

	reg.Register("searchTracksWithExtensions", func(params map[string]interface{}) (interface{}, error) {
		// Legacy alias — searches across all available source providers
		initSearchService()
		query := rpc.Sp(params, "query")
		if query == "" {
			return "[]", nil
		}
		limit := rpc.Sn(params, "limit")
		if limit <= 0 || limit > 50 {
			limit = 20
		}
		result, err := globalSearchService.Search(context.Background(), search.SearchRequest{
			Query: query, Type: "track", Mode: search.SearchModeUnified, Limit: limit,
		})
		if err != nil {
			return "[]", nil
		}
		b, _ := json.Marshal(result.Unified)
		return string(b), nil
	})

	reg.Register("searchTracksWithExtensionsJSON", func(params map[string]interface{}) (interface{}, error) {
		initSearchService()
		query := rpc.Sp(params, "query")
		if query == "" {
			return "[]", nil
		}
		limit := rpc.Sn(params, "limit")
		if limit <= 0 || limit > 50 {
			limit = 20
		}
		result, err := globalSearchService.Search(context.Background(), search.SearchRequest{
			Query: query, Type: "track", Mode: search.SearchModeUnified, Limit: limit,
		})
		if err != nil {
			return "[]", nil
		}
		b, _ := json.Marshal(result.Unified)
		return string(b), nil
	})

	reg.Register("searchAlbumTracksJSON", func(params map[string]interface{}) (interface{}, error) {
		query := rpc.Sp(params, "query")
		if query == "" {
			return "[]", nil
		}
		initSearchService()
		result, err := globalSearchService.Search(context.Background(), search.SearchRequest{
			Query: strings.TrimSpace(query), Type: "track",
			Mode: search.SearchModeUnified, Limit: 50,
		})
		if err != nil {
			return "[]", nil
		}
		b, _ := json.Marshal(result.Unified)
		return string(b), nil
	})
}
