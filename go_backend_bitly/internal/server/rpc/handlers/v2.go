package handlers

import "github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"

func RegisterV2Handlers(reg *rpc.Registry) {
	registerV2Migration(reg)
	registerV2Artists(reg)
	registerV2Albums(reg)
	registerV2Tracks(reg)
	registerV2Collections(reg)
	registerV2Wishlist(reg)
	registerV2Other(reg)
}
