package handlers

import (
	"context"

	"github.com/zarz/bitly/go_backend_bitly/internal/search"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/availability"
)

func registerSearchAvailability(reg *rpc.Registry) {
	reg.Register("searchAndCheckAvailability", func(params map[string]interface{}) (interface{}, error) {
		initSearchService()
		query := rpc.Sp(params, "query")
		if query == "" {
			return nil, nil
		}
		spotifyID := rpc.Sp(params, "spotify_id")
		isrc := rpc.Sp(params, "isrc")
		if spotifyID != "" || isrc != "" {
			client := availability.NewClient()
			result, err := client.CheckTrackAvailability(spotifyID, isrc)
			if err != nil {
				return nil, err
			}
			return result, nil
		}
		result, err := globalSearchService.Search(context.Background(), search.SearchRequest{
			Query: query, Type: "track", Mode: search.SearchModeUnified, Limit: 5,
		})
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("resolveTrackByISRC", func(params map[string]interface{}) (interface{}, error) {
		resolver := availability.GetLinkResolver()
		isrc := rpc.Sp(params, "isrc")
		result, err := resolver.ResolveByISRC(isrc)
		if err != nil {
			return nil, err
		}
		return result, nil
	})
}
