package handlers

import "github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"

func RegisterMetadataHandlers(reg *rpc.Registry) {
	registerMetadataRead(reg)
	registerMetadataEdit(reg)
	registerMetadataCover(reg)
	registerMetadataReEnrich(reg)
	registerMetadataUtils(reg)
}
