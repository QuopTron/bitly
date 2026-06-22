package handlers

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func parseStringSliceParam(params map[string]interface{}, key string) []string {
	raw, ok := params[key]
	if !ok {
		return nil
	}
	switch v := raw.(type) {
	case []interface{}:
		result := make([]string, 0, len(v))
		for _, item := range v {
			s, _ := item.(string)
			if s != "" {
				result = append(result, s)
			}
		}
		return result
	case string:
		if v == "" {
			return nil
		}
		var result []string
		if err := json.Unmarshal([]byte(v), &result); err == nil {
			return result
		}
		return []string{v}
	default:
		return nil
	}
}

func RegisterAvailabilityHandlers(reg *rpc.Registry) {
	registerAvailabilitySongLink(reg)
	registerAvailabilitySongLink2(reg)
	registerAvailabilityIDHS(reg)
}
