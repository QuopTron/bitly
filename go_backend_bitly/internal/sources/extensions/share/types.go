package share

import (
	"sync"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/api"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manager"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/runtime"
)

type CrossExtensionShareResult struct {
	ExtensionID string `json:"extension_id"`
	DisplayName string `json:"display_name"`
	Found       bool   `json:"found"`
	URL         string `json:"url,omitempty"`
	ItemName    string `json:"item_name,omitempty"`
	ItemArtists string `json:"item_artists,omitempty"`
	Error       string `json:"error,omitempty"`
}

type extTrack struct {
	ID            string            `json:"id"`
	Name          string            `json:"name"`
	Artists       string            `json:"artists"`
	AlbumName     string            `json:"album_name"`
	AlbumArtist   string            `json:"album_artist,omitempty"`
	DurationMS    int               `json:"duration_ms"`
	CoverURL      string            `json:"cover_url,omitempty"`
	ISRC          string            `json:"isrc,omitempty"`
	ItemType      string            `json:"item_type,omitempty"`
	ExternalURL   string            `json:"external_url,omitempty"`
	AlbumURL      string            `json:"album_url,omitempty"`
	ArtistURL     string            `json:"artist_url,omitempty"`
	AlbumID       string            `json:"album_id,omitempty"`
	ArtistID      string            `json:"artist_id,omitempty"`
	ExternalLinks map[string]string `json:"external_links,omitempty"`
}

const maxCacheEntries = 128

type Service struct {
	manager  *manager.Manager
	runtime  *runtime.ExtensionRuntime
	client   *api.ActionClient
	cacheMu  sync.RWMutex
	cache    map[string]string
	cacheOrd []string
}

func NewService(mgr *manager.Manager, rt *runtime.ExtensionRuntime) *Service {
	return &Service{
		manager: mgr,
		runtime: rt,
		client:  api.NewActionClient(rt),
		cache:   make(map[string]string),
	}
}
