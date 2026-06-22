package handlers

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/lyrics"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerLyricsTranslate(reg *rpc.Registry) {
	reg.Register("getTranslatedLyricsLRC", func(params map[string]interface{}) (interface{}, error) {
		trackName := rpc.Sp(params, "track_name")
		artistName := rpc.Sp(params, "artist_name")
		durationMs := int64(rpc.Sn(params, "duration_ms"))
		language := rpc.Sp(params, "language")

		if language == "" {
			return "", nil
		}

		client := lyrics.NewMusixmatchClient()
		durationSec := float64(durationMs) / 1000.0
		lyricsResult, err := client.FetchLyricsInLanguage(trackName, artistName, durationSec, language)
		if err != nil {
			return "", err
		}
		if lyricsResult.Instrumental {
			return "[instrumental:true]", nil
		}
		return lyrics.ConvertToLRCWithMetadata(lyricsResult, trackName, artistName), nil
	})
}
