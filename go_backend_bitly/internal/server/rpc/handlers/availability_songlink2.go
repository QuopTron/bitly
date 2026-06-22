package handlers

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/availability"
)

func registerAvailabilitySongLink2(reg *rpc.Registry) {
	reg.Register("getSpotifyIDFromDeezer", func(params map[string]interface{}) (interface{}, error) {
		client := availability.NewClient()
		spotifyID, err := client.GetSpotifyIDFromDeezer(rpc.Sp(params, "deezer_id"))
		if err != nil {
			return nil, err
		}
		return spotifyID, nil
	})

	reg.Register("getAmazonURLFromDeezer", func(params map[string]interface{}) (interface{}, error) {
		client := availability.NewClient()
		amazonURL, err := client.GetAmazonURLFromDeezer(rpc.Sp(params, "deezer_id"))
		if err != nil {
			return nil, err
		}
		return amazonURL, nil
	})

	reg.Register("getYouTubeURLFromDeezer", func(params map[string]interface{}) (interface{}, error) {
		client := availability.NewClient()
		ytURL, err := client.GetYouTubeURLFromDeezer(rpc.Sp(params, "deezer_id"))
		if err != nil {
			return nil, err
		}
		return ytURL, nil
	})

	reg.Register("getDeezerAlbumIDFromSpotify", func(params map[string]interface{}) (interface{}, error) {
		client := availability.NewClient()
		deezerAlbumID, err := client.GetDeezerAlbumIDFromSpotify(rpc.Sp(params, "spotify_album_id"))
		if err != nil {
			return nil, err
		}
		return deezerAlbumID, nil
	})

	reg.Register("setSongLinkRegion", func(params map[string]interface{}) (interface{}, error) {
		region := rpc.Sp(params, "region")
		if region == "" {
			region = "US"
		}
		availability.SetRegion(region)
		return "ok", nil
	})
}
