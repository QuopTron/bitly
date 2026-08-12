package gobackend

import (
	"encoding/json"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

const searchGlobalTimeout = 15 * time.Second

// namedResult holds one provider's search results for generic searchByProvider.
type namedResult[T any] struct {
	Provider string `json:"provider"`
	Results  []T    `json:"results"`
}

// namedTrack holds one provider's track results (JSON field "tracks").
type namedTrack struct {
	Provider string                `json:"provider"`
	Tracks   []provider.TrackResult `json:"tracks"`
}

// searchAll runs fn for every registered provider in parallel.
// Returns after searchGlobalTimeout or when all providers finish.
func searchAll[T any](query string, limit int,
	fn func(provider.Provider, string, int) ([]T, error),
) []namedResult[T] {
	return searchAllWithTimeout(query, limit, fn, searchGlobalTimeout)
}

// searchAllWithTimeout runs fn for every registered provider in parallel.
// Returns after the given timeout or when all providers finish.
func searchAllWithTimeout[T any](query string, limit int,
	fn func(provider.Provider, string, int) ([]T, error),
	searchTimeout time.Duration,
) []namedResult[T] {
	if reg == nil {
		return nil
	}
	providers := reg.All()
	if len(providers) == 0 {
		return nil
	}

	type item struct {
		name string
		data []T
	}
	ch := make(chan item, len(providers))

	var wg sync.WaitGroup
	for _, p := range providers {
		wg.Add(1)
		go func(prov provider.Provider) {
			defer wg.Done()
			defer func() {
				if rec := recover(); rec != nil {
					// Don't crash the app if a provider panics
				}
			}()
			// Circuit breaker: a provider cooling down from rate-limits is
			// skipped fast instead of re-hitting its API for every keystroke.
			if cooldown.IsCooled(prov.Name()) {
				return
			}
			res, err := fn(prov, query, limit)
			if err == nil && len(res) > 0 {
				ch <- item{name: prov.Name(), data: res}
			}
		}(p)
	}

	go func() {
		wg.Wait()
		close(ch)
	}()

	results := make([]namedResult[T], 0)
	timeout := time.After(searchTimeout)
	collecting := true
	for collecting {
		select {
		case r, ok := <-ch:
			if !ok {
				collecting = false
				break
			}
			results = append(results, namedResult[T]{
				Provider: r.name,
				Results:  r.data,
			})
		case <-timeout:
			collecting = false
		}
	}
	return results
}

// =========================================================================
// SEARCH
// =========================================================================

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

func GetTrack(payload string) string {
	if reg == nil {
		return `{"error":"no inicializado"}`
	}
	var params struct {
		ProviderName string `json:"providerName"`
		TrackID      string `json:"trackID"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	p := reg.Get(params.ProviderName)
	if p == nil {
		return jsonErrorStr("proveedor no encontrado")
	}
	track, err := p.GetTrack(params.TrackID)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(track)
	return string(data)
}

func GetAlbum(payload string) string {
	if reg == nil {
		return `{"error":"no inicializado"}`
	}
	var params struct {
		ProviderName string `json:"providerName"`
		AlbumID      string `json:"albumID"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	p := reg.Get(params.ProviderName)
	if p == nil {
		return jsonErrorStr("proveedor no encontrado")
	}
	album, err := p.GetAlbum(params.AlbumID)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(album)
	return string(data)
}

func GetArtist(payload string) string {
	if reg == nil {
		return `{"error":"no inicializado"}`
	}
	var params struct {
		ProviderName string `json:"providerName"`
		ArtistID     string `json:"artistID"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	p := reg.Get(params.ProviderName)
	if p == nil {
		return jsonErrorStr("proveedor no encontrado")
	}
	artist, err := p.GetArtist(params.ArtistID)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(artist)
	return string(data)
}

func ResolveISRC(isrc string) string {
	if searchEngine == nil {
		return `{"error":"no inicializado"}`
	}
	results, err := searchEngine.SearchTracks(`isrc:"`+isrc+`"`, 5)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(results)
	return string(data)
}
