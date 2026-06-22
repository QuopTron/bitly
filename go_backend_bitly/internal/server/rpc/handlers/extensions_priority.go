package handlers

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerExtensionPriority(reg *rpc.Registry) {
	reg.Register("getProviderPriority", func(params map[string]interface{}) (interface{}, error) {
		providerPriorityMu.RLock()
		defer providerPriorityMu.RUnlock()
		if len(providerPriority) == 0 {
			return "[]", nil
		}
		b, _ := json.Marshal(providerPriority)
		return string(b), nil
	})

	reg.Register("setProviderPriority", func(params map[string]interface{}) (interface{}, error) {
		priorityRaw := rpc.Sp(params, "priority")
		if priorityRaw != "" {
			var ids []string
			if err := json.Unmarshal([]byte(priorityRaw), &ids); err == nil {
				providerPriorityMu.Lock()
				providerPriority = ids
				providerPriorityMu.Unlock()
			}
		}
		return "ok", nil
	})

	reg.Register("setDownloadFallbackExtensionIds", func(params map[string]interface{}) (interface{}, error) {
		idsRaw := rpc.Sp(params, "extension_ids")
		if idsRaw != "" {
			var ids []string
			if err := json.Unmarshal([]byte(idsRaw), &ids); err == nil {
				fallbackExtensionIDsMu.Lock()
				fallbackExtensionIDs = ids
				fallbackExtensionIDsMu.Unlock()
			}
		}
		return "ok", nil
	})

	reg.Register("getMetadataProviderPriority", func(params map[string]interface{}) (interface{}, error) {
		metadataProviderPriorityMu.RLock()
		defer metadataProviderPriorityMu.RUnlock()
		if len(metadataProviderPriority) == 0 {
			return "[]", nil
		}
		b, _ := json.Marshal(metadataProviderPriority)
		return string(b), nil
	})

	reg.Register("setMetadataProviderPriority", func(params map[string]interface{}) (interface{}, error) {
		priorityRaw := rpc.Sp(params, "priority")
		if priorityRaw != "" {
			var ids []string
			if err := json.Unmarshal([]byte(priorityRaw), &ids); err == nil {
				metadataProviderPriorityMu.Lock()
				metadataProviderPriority = ids
				metadataProviderPriorityMu.Unlock()
			}
		}
		return "ok", nil
	})

	// JSON aliases for compatibility with old backend dispatch
	reg.Register("getProviderPriorityJSON", func(params map[string]interface{}) (interface{}, error) {
		providerPriorityMu.RLock()
		defer providerPriorityMu.RUnlock()
		if len(providerPriority) == 0 {
			return "[]", nil
		}
		b, _ := json.Marshal(providerPriority)
		return string(b), nil
	})

	reg.Register("setProviderPriorityJSON", func(params map[string]interface{}) (interface{}, error) {
		priorityRaw := rpc.Sp(params, "priority")
		if priorityRaw != "" {
			var ids []string
			if err := json.Unmarshal([]byte(priorityRaw), &ids); err == nil {
				providerPriorityMu.Lock()
				providerPriority = ids
				providerPriorityMu.Unlock()
			}
		}
		return "ok", nil
	})

	reg.Register("setDownloadFallbackExtensionIdsJSON", func(params map[string]interface{}) (interface{}, error) {
		idsRaw := rpc.Sp(params, "extension_ids")
		if idsRaw != "" {
			var ids []string
			if err := json.Unmarshal([]byte(idsRaw), &ids); err == nil {
				fallbackExtensionIDsMu.Lock()
				fallbackExtensionIDs = ids
				fallbackExtensionIDsMu.Unlock()
			}
		}
		return "ok", nil
	})

	reg.Register("getMetadataProviderPriorityJSON", func(params map[string]interface{}) (interface{}, error) {
		metadataProviderPriorityMu.RLock()
		defer metadataProviderPriorityMu.RUnlock()
		if len(metadataProviderPriority) == 0 {
			return "[]", nil
		}
		b, _ := json.Marshal(metadataProviderPriority)
		return string(b), nil
	})

	reg.Register("setMetadataProviderPriorityJSON", func(params map[string]interface{}) (interface{}, error) {
		priorityRaw := rpc.Sp(params, "priority")
		if priorityRaw != "" {
			var ids []string
			if err := json.Unmarshal([]byte(priorityRaw), &ids); err == nil {
				metadataProviderPriorityMu.Lock()
				metadataProviderPriority = ids
				metadataProviderPriorityMu.Unlock()
			}
		}
		return "ok", nil
	})
}
