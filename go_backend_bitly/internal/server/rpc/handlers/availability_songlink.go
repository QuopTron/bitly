package handlers

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/availability"
)

func registerAvailabilitySongLink(reg *rpc.Registry) {
	reg.Register("checkAvailability", func(params map[string]interface{}) (interface{}, error) {
		client := availability.NewClient()
		result, err := client.CheckTrackAvailability(rpc.Sp(params, "spotify_id"), rpc.Sp(params, "isrc"))
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("checkAvailabilityFromDeezer", func(params map[string]interface{}) (interface{}, error) {
		client := availability.NewClient()
		result, err := client.CheckAvailabilityFromDeezer(rpc.Sp(params, "deezer_id"))
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("checkAvailabilityByPlatform", func(params map[string]interface{}) (interface{}, error) {
		client := availability.NewClient()
		result, err := client.CheckAvailabilityByPlatform(
			rpc.Sp(params, "platform"), rpc.Sp(params, "entity_type"), rpc.Sp(params, "entity_id"))
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("checkAvailabilityFromURL", func(params map[string]interface{}) (interface{}, error) {
		client := availability.NewClient()
		result, err := client.CheckAvailabilityFromURL(rpc.Sp(params, "url"))
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("checkAlbumAvailability", func(params map[string]interface{}) (interface{}, error) {
		client := availability.NewClient()
		result, err := client.CheckAlbumAvailability(rpc.Sp(params, "spotify_album_id"))
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("getDeezerIDFromSpotify", func(params map[string]interface{}) (interface{}, error) {
		client := availability.NewClient()
		deezerID, err := client.GetDeezerIDFromSpotify(rpc.Sp(params, "spotify_id"))
		if err != nil {
			return nil, err
		}
		return deezerID, nil
	})

	reg.Register("getYouTubeURLFromSpotify", func(params map[string]interface{}) (interface{}, error) {
		client := availability.NewClient()
		ytURL, err := client.GetYouTubeURLFromSpotify(rpc.Sp(params, "spotify_id"))
		if err != nil {
			return nil, err
		}
		return ytURL, nil
	})

	reg.Register("getTidalURLFromDeezer", func(params map[string]interface{}) (interface{}, error) {
		client := availability.NewClient()
		tidalURL, err := client.GetTidalURLFromDeezer(rpc.Sp(params, "deezer_id"))
		if err != nil {
			return nil, err
		}
		return tidalURL, nil
	})

	reg.Register("getStreamingURLs", func(params map[string]interface{}) (interface{}, error) {
		client := availability.NewClient()
		urls, err := client.GetStreamingURLs(rpc.Sp(params, "spotify_id"))
		if err != nil {
			return nil, err
		}
		return urls, nil
	})
}
