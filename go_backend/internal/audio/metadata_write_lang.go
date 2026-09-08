package audio

import (
	"strings"
	"sync"
)

var mutexIdiomaMetadata struct {
	sync.RWMutex
	tag string
}

// SetMetadataLanguage sets the app's display language for metadata localization.
func SetMetadataLanguage(tag string) {
	mutexIdiomaMetadata.Lock()
	mutexIdiomaMetadata.tag = strings.TrimSpace(tag)
	mutexIdiomaMetadata.Unlock()
}

// MetadataAcceptLanguage returns the Accept-Language header for metadata requests.
func MetadataAcceptLanguage() string {
	mutexIdiomaMetadata.RLock()
	tag := mutexIdiomaMetadata.tag
	mutexIdiomaMetadata.RUnlock()
	if tag == "" || strings.HasPrefix(strings.ToLower(tag), "en") {
		return "en-US,en;q=0.9"
	}
	return tag + ",en;q=0.8"
}
