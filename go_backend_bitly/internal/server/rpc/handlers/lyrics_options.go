package handlers

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend_bitly/internal/lyrics"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerLyricsOptions(reg *rpc.Registry) {
	reg.Register("setLyricsFetchOptions", func(params map[string]interface{}) (interface{}, error) {
		optionsJSON := rpc.Sp(params, "options")
		if optionsJSON == "" {
			return "ok", nil
		}
		var opts lyrics.LyricsFetchOptions
		if err := json.Unmarshal([]byte(optionsJSON), &opts); err != nil {
			return nil, err
		}
		lyrics.SetLyricsFetchOptions(opts)
		return "ok", nil
	})

	reg.Register("getLyricsFetchOptions", func(params map[string]interface{}) (interface{}, error) {
		opts := lyrics.GetLyricsFetchOptions()
		return opts, nil
	})

	// JSON aliases for compatibility with old backend dispatch
	reg.Register("setLyricsFetchOptionsJSON", func(params map[string]interface{}) (interface{}, error) {
		optionsJSON := rpc.Sp(params, "options_json")
		if optionsJSON == "" {
			optionsJSON = rpc.Sp(params, "options")
		}
		if optionsJSON == "" {
			return "ok", nil
		}
		var opts lyrics.LyricsFetchOptions
		if err := json.Unmarshal([]byte(optionsJSON), &opts); err != nil {
			return nil, err
		}
		lyrics.SetLyricsFetchOptions(opts)
		return "ok", nil
	})

	reg.Register("getLyricsFetchOptionsJSON", func(params map[string]interface{}) (interface{}, error) {
		opts := lyrics.GetLyricsFetchOptions()
		b, _ := json.Marshal(opts)
		return string(b), nil
	})
}
