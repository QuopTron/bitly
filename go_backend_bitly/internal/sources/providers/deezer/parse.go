package deezer

import (
	"fmt"
	"net/url"
	"strings"
)

func ParseDeezerURL(input string) (resourceType, resourceID string, err error) {
	trimmed := strings.TrimSpace(input)
	if trimmed == "" {
		return "", "", fmt.Errorf("empty URL")
	}
	parsed, parseErr := url.Parse(trimmed)
	if parseErr != nil {
		return "", "", parseErr
	}
	if parsed.Host != "www.deezer.com" && parsed.Host != "deezer.com" && parsed.Host != "deezer.page.link" {
		return "", "", fmt.Errorf("not a Deezer URL")
	}
	parts := strings.Split(strings.Trim(parsed.Path, "/"), "/")
	if len(parts) > 0 && len(parts[0]) == 2 {
		parts = parts[1:]
	}
	if len(parts) < 2 {
		return "", "", fmt.Errorf("invalid Deezer URL format")
	}
	resourceType = parts[0]
	resourceID = parts[1]
	switch resourceType {
	case "track", "album", "artist", "playlist":
		return resourceType, resourceID, nil
	default:
		return "", "", fmt.Errorf("unsupported Deezer resource type: %s", resourceType)
	}
}
