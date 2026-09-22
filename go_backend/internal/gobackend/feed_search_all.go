package gobackend

import (
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// searchAllSourceBest searches every provider IN PARALLEL (with a global
// timeout) and returns the combined results from ALL of them, each capped at
// [limit]. A rate-limited (cooled) source is skipped fast. The Flutter side
// groups the returned items by source, so a "Todas" search shows every
// extension's results in its own section instead of only the primary source's
// — and no healthy source is ever left out of the results.
func searchAllSourceBest(query string, limit int, searchType string) string {
	if reg == nil {
		return `[]`
	}
	perSource := limit
	if perSource < 1 {
		perSource = 20
	}

	providers := providersBusquedaOrdenados()
	ch := make(chan []FeedItemGo, len(providers))
	var wg sync.WaitGroup
	for _, p := range providers {
		// Only skip providers cooled *for search*. Downloads/streaming cool their
		// own op buckets (or the provider-wide one), so a big download that
		// rate-limits a few providers must never leave the next search looking
		// "empty" — search always attempts every reachable source.
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
			// Cada proveedor con su propio techo (ver search_deadline.go): el más
			// lento se abandona a los 3 s en vez de consumir los 4 s de la
			// ventana global, así que el canal se cierra (y la búsqueda termina)
			// en cuanto el último proveedor útil responde.
			//
			// Se usa la variante que devuelve items: antes cada proveedor
			// serializaba a JSON y el agregador lo deserializaba enseguida (ver
			// itemsAJSON), duplicando el trabajo de TODOS los resultados.
			batch := conTimeoutProveedor(searchProviderTimeoutFanout, func() []FeedItemGo {
				return searchProviderItemsSync(p, query, perSource, searchType)
			}).valor
			if len(batch) > 0 {
				ch <- batch
			}
		}(p)
	}
	go func() { wg.Wait(); close(ch) }()

	items := make([]FeedItemGo, 0, len(providers)*perSource)
	// La ventana global queda como RED DE SEGURIDAD: con el techo por
	// proveedor ya no debería alcanzarse nunca, solo si el runtime de una
	// extensión se traga la cancelación y deja el goroutine vivo.
	timeout := time.After(searchGlobalTimeout)
	collecting := true
	for collecting {
		select {
		case batch, ok := <-ch:
			if !ok {
				collecting = false
				break
			}
			items = append(items, batch...)
		case <-timeout:
			collecting = false
		}
	}
	return itemsAJSON(items)
}

// searchAllSource searches all providers for a given type, using the
// sequential primary-first strategy (never firing every API in parallel).
// Acepta el manifest filter ids en singular/plural form ("canción"/"canciones",// "song"/"songs", ...) plus "all"/"" for the combined mix.
func searchAllSource(query string, limit int, searchType string) string {
	switch searchType {
	case "track", "tracks", "song", "songs", "album", "albums", "artist", "artists", "playlist", "playlists":
		return searchAllSourceBest(query, limit, searchType)
	case "all", "":
		return searchAllSourceBest(query, limit, "all")
	default:
		return `[]`
	}
}
