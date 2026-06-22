package handlers

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend_bitly/internal/lyrics"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerLyricsProviders(reg *rpc.Registry) {
	reg.Register("setLyricsProviders", func(params map[string]interface{}) (interface{}, error) {
		providersJSON := rpc.Sp(params, "providers")
		var providers []string
		if err := json.Unmarshal([]byte(providersJSON), &providers); err != nil {
			return nil, err
		}
		lyrics.SetLyricsProviderOrder(providers)
		return "ok", nil
	})

	reg.Register("getLyricsProviders", func(params map[string]interface{}) (interface{}, error) {
		providers := lyrics.GetLyricsProviderOrder()
		return providers, nil
	})

	reg.Register("getAvailableLyricsProviders", func(params map[string]interface{}) (interface{}, error) {
		providers := lyrics.GetAvailableLyricsProviders()
		return providers, nil
	})

	// JSON aliases for compatibility with old backend dispatch
	reg.Register("setLyricsProvidersJSON", func(params map[string]interface{}) (interface{}, error) {
		providersJSON := rpc.Sp(params, "providers_json")
		if providersJSON == "" {
			providersJSON = rpc.Sp(params, "providers")
		}
		var providers []string
		if err := json.Unmarshal([]byte(providersJSON), &providers); err != nil {
			return nil, err
		}
		lyrics.SetLyricsProviderOrder(providers)
		return "ok", nil
	})

	reg.Register("getLyricsProvidersJSON", func(params map[string]interface{}) (interface{}, error) {
		providers := lyrics.GetLyricsProviderOrder()
		b, _ := json.Marshal(providers)
		return string(b), nil
	})

	reg.Register("getAvailableLyricsProvidersJSON", func(params map[string]interface{}) (interface{}, error) {
		providers := lyrics.GetAvailableLyricsProviders()
		b, _ := json.Marshal(providers)
		return string(b), nil
	})
}
