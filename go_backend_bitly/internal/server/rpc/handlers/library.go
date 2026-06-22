package handlers

import "github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"

func RegisterLibraryHandlers(reg *rpc.Registry) {
	registerLibraryScan(reg)
	registerLibraryPages(reg)
	registerLibraryEntries(reg)
	registerLibraryMaintenance(reg)
}
