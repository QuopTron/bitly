package handlers

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerExtensionBrowse(reg *rpc.Registry) {
	reg.Register("getExtensionHomeFeed", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		extID := rpc.Sp(params, "extension_id")
		if extID == "" || !extRuntime.IsLoaded(extID) {
			return "[]", nil
		}
		result, err := extRuntime.CallMethod(extID, "getHomeFeed")
		if err != nil || result == nil {
			return "[]", nil
		}
		return result.RawJSON, nil
	})

	reg.Register("getExtensionBrowseCategories", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		extID := rpc.Sp(params, "extension_id")
		if extID == "" || !extRuntime.IsLoaded(extID) {
			return "[]", nil
		}
		result, err := extRuntime.CallMethod(extID, "getBrowseCategories")
		if err != nil || result == nil {
			return "[]", nil
		}
		return result.RawJSON, nil
	})

	reg.Register("cancelExtensionRequest", func(params map[string]interface{}) (interface{}, error) {
		reqID := rpc.Sp(params, "request_id")
		if reqID != "" {
			cancelReqMu.Lock()
			cancelReqs[reqID] = struct{}{}
			cancelReqMu.Unlock()
		}
		return "ok", nil
	})

	reg.Register("cancelExtensionRequestJSON", func(params map[string]interface{}) (interface{}, error) {
		reqID := rpc.Sp(params, "request_id")
		if reqID != "" {
			cancelReqMu.Lock()
			cancelReqs[reqID] = struct{}{}
			cancelReqMu.Unlock()
		}
		return "ok", nil
	})
}
