package handlers

import "github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"

func RegisterExtensionHandlers(reg *rpc.Registry) {
	registerExtensionLifecycle(reg)
	registerExtensionQuery(reg)
	registerExtensionInvoke(reg)
	registerExtensionPriority(reg)
	registerExtensionSettings(reg)
	registerExtensionAuth(reg)
	registerExtensionFFmpeg(reg)
	registerExtensionURL(reg)
	registerExtensionBrowse(reg)
	registerExtensionStore(reg)
	registerExtensionStoreExt(reg)
}
