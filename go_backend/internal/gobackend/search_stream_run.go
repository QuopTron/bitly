package gobackend

import (
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// runSearchStream executes the search in background, appending results to the
// shared buffer as each provider completes. Providers run in parallel; results
// are deduplicated by ISRC (for tracks) or by ID (for collections).
func runSearchStream(gen int64, query string, limit int, source string, searchType string) {
	if source == "" {
		// "Todas": search all providers, primary first
		searchAllStreamProviders(gen, query, limit, searchType)
	} else {
		// Single source
		p := reg.Get(source)
		if p == nil {
			for _, name := range reg.Names() {
				if plegadoIgual(name, source) {
					p = reg.Get(name)
					break
				}
			}
		}
		if p != nil {
			items := searchProviderItems(p, query, limit, searchType)
			anexarSearchStream(gen, items)
		}
	}

	currentSearchStream.mu.Lock()
	if currentSearchStream.generation == gen {
		currentSearchStream.done = true
	}
	currentSearchStream.mu.Unlock()
}

// searchAllStreamProviders runs all providers in parallel (primary first),
// appending results to the stream buffer as each one completes. Unlike
// searchAllSourceBest which waits for ALL providers before returning, this
// Streams resultados incrementalmente para que Flutter pueda mostrar resultados parciales.
func searchAllStreamProviders(gen int64, query string, limit int, searchType string) {
	if reg == nil {
		return
	}

	providers := providersBusquedaOrdenados()
	perSource := limit
	if perSource < 1 {
		perSource = 20
	}

	type namedBatch struct {
		name  string
		items []FeedItemGo
	}
	ch := make(chan namedBatch, len(providers))

	var wg sync.WaitGroup
	for _, p := range providers {
		if cooldown.IsCooledOp(p.Name(), "search") {
			continue
		}
		wg.Add(1)
		go func(p provider.Provider) {
			defer wg.Done()
			defer func() {
				if rec := recover(); rec != nil {
					// Never crash the app if a provider panics mid-search.
				}
			}()
			items := searchProviderItems(p, query, perSource, searchType)
			if len(items) > 0 {
				ch <- namedBatch{name: p.Name(), items: items}
			}
		}(p)
	}
	go func() { wg.Wait(); close(ch) }()

	timeout := time.After(searchGlobalTimeout)
	for {
		select {
		case batch, ok := <-ch:
			if !ok {
				return
			}
			anexarSearchStream(gen, batch.items)
		case <-timeout:
			return
		}
	}
}
