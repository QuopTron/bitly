package handlers

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerLibraryScan(reg *rpc.Registry) {
	reg.Register("scanLibraryFolder", func(params map[string]interface{}) (interface{}, error) {
		return "[]", nil
	})

	reg.Register("scanLibraryFolderIncremental", func(params map[string]interface{}) (interface{}, error) {
		return "[]", nil
	})

	reg.Register("scanLibraryFolderIncrementalFromSnapshot", func(params map[string]interface{}) (interface{}, error) {
		return "[]", nil
	})

	reg.Register("scanSafTreeIncremental", func(params map[string]interface{}) (interface{}, error) {
		return "[]", nil
	})

	reg.Register("scanSafTreeIncrementalFromSnapshot", func(params map[string]interface{}) (interface{}, error) {
		return "[]", nil
	})

	reg.Register("getLibraryScanProgress", func(params map[string]interface{}) (interface{}, error) {
		return "{}", nil
	})

	reg.Register("cancelLibraryScan", func(params map[string]interface{}) (interface{}, error) {
		return "ok", nil
	})

	reg.Register("setLibraryCoverCacheDir", func(params map[string]interface{}) (interface{}, error) {
		return "ok", nil
	})
}
