package handlers

import "github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"

func RegisterLyricsHandlers(reg *rpc.Registry) {
	registerLyricsFetch(reg)
	registerLyricsEmbed(reg)
	registerLyricsProviders(reg)
	registerLyricsOptions(reg)
	registerLyricsTranslate(reg)
	registerLyricsTranslationHandlers(reg)
}
