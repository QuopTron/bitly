package gobackend

import (
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

type namedResult[T any] struct {
	Provider string `json:"provider"`
	Results  []T    `json:"results"`
}

// namedTrack holds one provider's track results (JSON field "tracks").
type namedTrack struct {
	Provider string                 `json:"provider"`
	Tracks   []provider.TrackResult `json:"tracks"`
}

// searchAll ejecuta fn para cada proveedor registrado en paralelo.
// Devuelve tras searchGlobalTimeout o cuando todos los proveedores terminan.
func searchAll[T any](query string, limit int,
	fn func(provider.Provider, string, int) ([]T, error),
) []namedResult[T] {
	return searchAllWithTimeout(query, limit, fn, searchGlobalTimeout)
}

// searchAllWithTimeout ejecuta fn para cada proveedor registrado en paralelo.
// Devuelve tras el timeout dado o cuando todos los proveedores terminan.
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
			// Circuit breaker: skip only providers cooled for search (not
			// provider-wide, which streaming/download errors trip). Search has its
			// own "search" op bucket so a playback rate-limit never empties the
			// next search.
			if cooldown.IsCooledOp(prov.Name(), "search") {
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
