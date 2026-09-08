package gobackend

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

func SearchTracks(query string) string {
	if reg == nil {
		return `{"error":"no inicializado"}`
	}
	raw := searchAll(query, 10, func(p provider.Provider, q string, l int) ([]provider.TrackResult, error) {
		return p.SearchTracks(q, l)
	})
	results := make([]namedTrack, 0, len(raw))
	for _, r := range raw {
		results = append(results, namedTrack{Provider: r.Provider, Tracks: r.Results})
	}
	data, _ := json.Marshal(results)
	return string(data)
}

func searchByProvider[T any](query string, limit int,
	fn func(provider.Provider, string, int) ([]T, error),
) string {
	if reg == nil {
		return `{"error":"no inicializado"}`
	}
	results := searchAll(query, limit, fn)
	data, _ := json.Marshal(results)
	return string(data)
}

func SearchAlbums(query string) string {
	return searchByProvider(query, 5, func(p provider.Provider, q string, l int) ([]provider.AlbumResult, error) {
		return p.SearchAlbums(q, l)
	})
}

func SearchPlaylists(query string) string {
	return searchByProvider(query, 5, func(p provider.Provider, q string, l int) ([]provider.PlaylistResult, error) {
		return p.SearchPlaylists(q, l)
	})
}

func SearchArtists(query string) string {
	return searchByProvider(query, 5, func(p provider.Provider, q string, l int) ([]provider.ArtistResult, error) {
		return p.SearchArtists(q, l)
	})
}

// =========================================================================
// METADATA
// =========================================================================
