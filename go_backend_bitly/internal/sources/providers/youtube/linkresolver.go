package youtube

import (
	"fmt"
	"net/http"
	"sync"
	"time"
)

type ISRCResolutionResult struct {
	ISRC       string `json:"isrc"`
	TidalURL   string `json:"tidal_url,omitempty"`
	QobuzURL   string `json:"qobuz_url,omitempty"`
	DeezerURL  string `json:"deezer_url,omitempty"`
	SpotifyURL string `json:"spotify_url,omitempty"`
	Provider   string `json:"provider"`
}

type LinkResolver struct {
	httpClient       *http.Client
	resolverPriority []string
}

var (
	linkResolver     *LinkResolver
	linkResolverOnce sync.Once
)

func GetLinkResolver() *LinkResolver {
	linkResolverOnce.Do(func() {
		linkResolver = &LinkResolver{
			httpClient: &http.Client{
				Timeout: 30 * time.Second,
			},
			resolverPriority: []string{"deezer_songlink", "songstats"},
		}
	})
	return linkResolver
}

func (lr *LinkResolver) ResolveByISRC(isrc string) (*ISRCResolutionResult, error) {
	for _, provider := range lr.resolverPriority {
		switch provider {
		case "deezer_songlink":
			result, err := lr.resolveViaDeezerSonglink(isrc)
			if err == nil && result != nil {
				result.Provider = "deezer_songlink"
				return result, nil
			}
		case "songstats":
			result, err := lr.resolveViaSongstats(isrc)
			if err == nil && result != nil {
				result.Provider = "songstats"
				return result, nil
			}
		}
	}
	return nil, fmt.Errorf("all link resolvers failed for ISRC: %s", isrc)
}
