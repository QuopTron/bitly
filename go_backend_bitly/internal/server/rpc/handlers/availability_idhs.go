package handlers

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/availability"
)

func registerAvailabilityIDHS(reg *rpc.Registry) {
	reg.Register("idhsSearchSpotify", func(params map[string]interface{}) (interface{}, error) {
		client := availability.NewIDHSClient()
		result, err := client.GetAvailabilityFromSpotify(rpc.Sp(params, "spotify_id"))
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("idhsSearchDeezer", func(params map[string]interface{}) (interface{}, error) {
		client := availability.NewIDHSClient()
		result, err := client.GetAvailabilityFromDeezer(rpc.Sp(params, "deezer_id"))
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("idhsSearchByURL", func(params map[string]interface{}) (interface{}, error) {
		client := availability.NewIDHSClient()
		link := rpc.Sp(params, "link")
		adapters := parseStringSliceParam(params, "adapters")
		result, err := client.Search(link, adapters)
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("resolveByISRC", func(params map[string]interface{}) (interface{}, error) {
		resolver := availability.GetLinkResolver()
		result, err := resolver.ResolveByISRC(rpc.Sp(params, "isrc"))
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("isrcFromSpotify", func(params map[string]interface{}) (interface{}, error) {
		resolver := availability.GetLinkResolver()
		isrc, err := resolver.ISRCFromSpotify(rpc.Sp(params, "spotify_id"))
		if err != nil {
			return nil, err
		}
		return isrc, nil
	})
}
