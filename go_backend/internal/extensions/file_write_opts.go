package extensions

import (
	"fmt"
	"strings"
)

func runtimeOptString(opts map[string]interface{}, key, def string) string {
	if opts == nil {
		return def
	}
	raw, ok := opts[key]
	if !ok || raw == nil {
		return def
	}
	if s, ok := raw.(string); ok {
		if t := strings.TrimSpace(s); t != "" {
			return t
		}
	}
	return def
}

func runtimeOptBool(opts map[string]interface{}, key string, def bool) bool {
	if opts == nil {
		return def
	}
	raw, ok := opts[key]
	if !ok || raw == nil {
		return def
	}
	switch v := raw.(type) {
	case bool:
		return v
	case int:
		return v != 0
	case int64:
		return v != 0
	case float64:
		return v != 0
	case string:
		switch strings.ToLower(strings.TrimSpace(v)) {
		case "1", "true", "yes", "on":
			return true
		case "0", "false", "no", "off":
			return false
		}
	}
	return def
}

func runtimeOptInt64(opts map[string]interface{}, key string, def int64) int64 {
	if opts == nil {
		return def
	}
	raw, ok := opts[key]
	if !ok || raw == nil {
		return def
	}
	switch v := raw.(type) {
	case int:
		return int64(v)
	case int32:
		return int64(v)
	case int64:
		return v
	case float32:
		return int64(v)
	case float64:
		return int64(v)
	case string:
		v = strings.TrimSpace(v)
		if v == "" {
			return def
		}
		var parsed int64
		if _, err := fmt.Sscanf(v, "%d", &parsed); err == nil {
			return parsed
		}
	}
	return def
}

func runtimeOptHasKey(opts map[string]interface{}, key string) bool {
	if opts == nil {
		return false
	}
	_, exists := opts[key]
	return exists
}
