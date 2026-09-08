package gobackend

import (
	"encoding/json"
)

// =========================================================================
// LIBRARY
// =========================================================================

func ScanLibrary(directory string) string {
	if lib == nil {
		return `{"error":"no inicializado"}`
	}
	entries, err := lib.Scan(directory)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(entries)
	return string(data)
}

func GetLibraryStats() string {
	if lib == nil {
		return `{}`
	}
	data, _ := json.Marshal(lib.GetStats())
	return string(data)
}
