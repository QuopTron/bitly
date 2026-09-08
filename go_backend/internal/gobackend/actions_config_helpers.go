package gobackend

import (
	"encoding/json"
	"strconv"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
)

// strOf reads the first non-empty string from a set of JSON keys.
func strOf(m map[string]interface{}, keys ...string) string {
	for _, k := range keys {
		if v, ok := m[k]; ok && v != nil {
			if s, ok := v.(string); ok && s != "" {
				return s
			}
		}
	}
	return ""
}

// strInt reads the first non-zero int from a set of JSON keys.
func strInt(m map[string]interface{}, keys ...string) int {
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

// bitrateForQuality returns the approximate bitrate (kbps) for a quality label.
func bitrateParaCalidad(q string) int {
	switch q {
	case "FLAC", "LOSSLESS", "HI_RES":
		return 1000
	case "320", "MP3_320":
		return 320
	case "256":
		return 256
	case "192":
		return 192
	case "128", "MP3_128":
		return 128
	default:
		return 1000
	}
}

// GetProviderHealthStatus returns cooldown status of all providers.
func GetProviderHealthStatus() string {
	status := cooldown.GetAllStatus()
	data, _ := json.Marshal(status)
	if data == nil {
		return "[]"
	}
	return string(data)
}
