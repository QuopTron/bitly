package gobackend

import (
	"strconv"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// providerByName finds a provider by name (case-insensitive).
func providerPorNombre(name string) provider.Provider {
	if reg == nil {
		return nil
	}
	if p := reg.Get(name); p != nil {
		return p
	}
	for _, n := range reg.Names() {
		if strings.EqualFold(n, name) {
			return reg.Get(n)
		}
	}
	return nil
}

func stringDetalle(m map[string]interface{}, keys ...string) string {
	for _, k := range keys {
		if v, ok := m[k]; ok && v != nil {
			if s, ok := v.(string); ok && s != "" {
				return s
			}
		}
	}
	return ""
}

// detailInt reads the first non-zero int from a list of keys.
func intDetalle(m map[string]interface{}, keys ...string) int {
	for _, k := range keys {
		if v, ok := m[k]; ok && v != nil {
			switch n := v.(type) {
			case float64:
				return int(n)
			case int64:
				return int(n)
			case int:
				return n
			case string:
				if out, err := strconv.Atoi(n); err == nil {
					return out
				}
			}
		}
	}
	return 0
}

// detailCover resolves a cover URL from the common key shapes.
func portadaDetalle(m map[string]interface{}) string {
	for _, k := range []string{"cover_url", "coverUrl", "cover", "images", "image_url", "imageUrl", "picture", "picture_xl", "thumbnail"} {
		v, ok := m[k]
		if !ok || v == nil {
			continue
		}
		if s, ok := v.(string); ok && s != "" {
			return s
		}
		// images can be an array of {url} or a string
		if arr, ok := v.([]interface{}); ok && len(arr) > 0 {
			if first, ok := arr[0].(map[string]interface{}); ok {
				if s := stringDetalle(first, "url", "href", "src"); s != "" {
					return s
				}
			}
			if s, ok := arr[0].(string); ok {
				return s
			}
		}
	}
	return ""
}
