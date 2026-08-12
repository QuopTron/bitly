package tidal

import "strings"

// coverURL builds a resources.tidal.com image URL from a Tidal image UUID.
//
// The Tidal CDN now only serves the "origin" size; every sized variant
// (320x320, 750x750, 1280x1280, ...) returns HTTP 403 AccessDenied.
// Full URLs (already http...) are returned unchanged.
func coverURL(uuid string) string {
	uuid = strings.TrimSpace(uuid)
	if uuid == "" || strings.HasPrefix(uuid, "http") {
		return uuid
	}
	return "https://resources.tidal.com/images/" +
		strings.ReplaceAll(uuid, "-", "/") + "/origin.jpg"
}
