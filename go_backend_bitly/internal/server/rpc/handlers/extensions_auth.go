package handlers

import (
	"encoding/json"
	"sort"
	"strconv"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerExtensionAuth(reg *rpc.Registry) {
	reg.Register("getExtensionPendingAuth", func(params map[string]interface{}) (interface{}, error) {
		extID := rpc.Sp(params, "extension_id")
		if extID == "" {
			return "{}", nil
		}
		extAuthMu.RLock()
		entry, ok := extAuthState[extID]
		extAuthMu.RUnlock()
		if !ok || entry.PendingAuthURL == "" {
			return "{}", nil
		}
		b, _ := json.Marshal(map[string]interface{}{
			"auth_url":  entry.PendingAuthURL,
			"auth_code": entry.AuthCode,
		})
		return string(b), nil
	})

	reg.Register("setExtensionAuthCode", func(params map[string]interface{}) (interface{}, error) {
		extID := rpc.Sp(params, "extension_id")
		code := rpc.Sp(params, "code")
		if extID == "" {
			return "ok", nil
		}
		extAuthMu.Lock()
		entry, ok := extAuthState[extID]
		if !ok {
			entry = &extensionAuthEntry{}
			extAuthState[extID] = entry
		}
		entry.AuthCode = code
		extAuthMu.Unlock()
		return "ok", nil
	})

	reg.Register("setExtensionTokens", func(params map[string]interface{}) (interface{}, error) {
		extID := rpc.Sp(params, "extension_id")
		if extID == "" {
			return "ok", nil
		}
		extAuthMu.Lock()
		entry, ok := extAuthState[extID]
		if !ok {
			entry = &extensionAuthEntry{}
			extAuthState[extID] = entry
		}
		entry.AccessToken = rpc.Sp(params, "access_token")
		entry.RefreshToken = rpc.Sp(params, "refresh_token")
		entry.IsAuthenticated = entry.AccessToken != ""
		entry.AuthCode = ""
		entry.PendingAuthURL = ""
		extAuthMu.Unlock()
		return "ok", nil
	})

	reg.Register("clearExtensionPendingAuth", func(params map[string]interface{}) (interface{}, error) {
		extID := rpc.Sp(params, "extension_id")
		if extID == "" {
			return "ok", nil
		}
		extAuthMu.Lock()
		entry, ok := extAuthState[extID]
		if ok {
			entry.PendingAuthURL = ""
			entry.AuthCode = ""
		}
		extAuthMu.Unlock()
		return "ok", nil
	})

	reg.Register("isExtensionAuthenticated", func(params map[string]interface{}) (interface{}, error) {
		extID := rpc.Sp(params, "extension_id")
		if extID == "" {
			return strconv.FormatBool(false), nil
		}
		extAuthMu.RLock()
		entry, ok := extAuthState[extID]
		extAuthMu.RUnlock()
		return strconv.FormatBool(ok && entry.IsAuthenticated), nil
	})

	reg.Register("getAllPendingAuthRequests", func(params map[string]interface{}) (interface{}, error) {
		extAuthMu.RLock()
		var requests []map[string]interface{}
		for id, entry := range extAuthState {
			if entry.PendingAuthURL != "" {
				requests = append(requests, map[string]interface{}{
					"extension_id": id,
					"auth_url":     entry.PendingAuthURL,
				})
			}
		}
		extAuthMu.RUnlock()
		if requests == nil {
			return "[]", nil
		}
		sort.Slice(requests, func(i, j int) bool {
			return requests[i]["extension_id"].(string) < requests[j]["extension_id"].(string)
		})
		b, _ := json.Marshal(requests)
		return string(b), nil
	})
}
