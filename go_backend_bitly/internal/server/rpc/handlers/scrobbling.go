package handlers

import (
	"fmt"

	"github.com/zarz/bitly/go_backend_bitly/internal/scrobble"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

// RegisterScrobblingHandlers registers scrobbling-related RPC methods for
// Last.fm and ListenBrainz support.
//
// Available methods:
//   - setupScrobbling(configJSON)        — saves scrobbling configuration
//   - getScrobblingConfig()              — returns current configuration
//   - scrobbleNowPlaying(trackJSON)      — sends "now playing" to enabled services
//   - scrobbleTrack(trackJSON)           — sends final scrobble to enabled services
func RegisterScrobblingHandlers(reg *rpc.Registry) {
	reg.Register("setupScrobbling", func(params map[string]interface{}) (interface{}, error) {
		config := rpc.Sp(params, "config")
		if config == "" {
			return nil, fmt.Errorf("missing param: config")
		}
		if err := scrobble.SetupConfig(config); err != nil {
			return nil, err
		}
		return "ok", nil
	})

	reg.Register("getScrobblingConfig", func(params map[string]interface{}) (interface{}, error) {
		cfg, err := scrobble.GetConfig()
		if err != nil {
			return "{}", nil
		}
		return cfg, nil
	})

	reg.Register("scrobbleNowPlaying", func(params map[string]interface{}) (interface{}, error) {
		track := rpc.Sp(params, "track")
		if track == "" {
			return nil, fmt.Errorf("missing param: track")
		}
		if err := scrobble.NowPlaying(track); err != nil {
			return nil, err
		}
		return "ok", nil
	})

	reg.Register("scrobbleTrack", func(params map[string]interface{}) (interface{}, error) {
		track := rpc.Sp(params, "track")
		if track == "" {
			return nil, fmt.Errorf("missing param: track")
		}
		if err := scrobble.Scrobble(track); err != nil {
			return nil, err
		}
		return "ok", nil
	})
}
