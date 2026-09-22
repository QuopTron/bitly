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
		if p == nil {
			// Fuente pedida que no existe en el registro: no se le pudo preguntar
			// a nadie. Se anota como fallida para que la UI no lo lea como
			// "sin resultados".
			registrarProveedorStream(gen, source, true)
		} else {
			// Fuente elegida a propósito: techo más generoso, pero acotado.
			res := conTimeoutProveedor(searchFuenteUnicaTimeout, func() resultadoItems {
				items, fallo := searchProviderItems(p, query, limit, searchType)
				return resultadoItems{items: items, fallo: fallo}
			})
			// Vencer el techo también es "no respondió" (res.ok == false).
			anexarSearchStream(gen, res.valor.items)
			registrarProveedorStream(gen, p.Name(), res.valor.fallo || !res.ok)
		}
	}

	// Red de identidad: si las extensiones no devolvieron NINGUNA canción,
	// Last.fm aporta el nombre canónico y el video oficial de YouTube (ver
	// search_lastfm_rescate.go). Va antes de marcar `done` para que la lista
	// llegue completa en el último sondeo.
	reforzarBusquedaConLastfm(gen, query, source, searchType)

	currentSearchStream.mu.Lock()
	if currentSearchStream.generation == gen {
		currentSearchStream.done = true
		// `done` va dentro de la respuesta: la cadena cacheada ya no vale.
		currentSearchStream.jsonCache = ""
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
			// Ni siquiera se le preguntó: cuenta como no respondida (si no, la
			// búsqueda "Todas" diría "sin resultados" habiendo saltado fuentes).
			registrarProveedorStream(gen, p.Name(), true)
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
			// Techo por proveedor = la MISMA ventana global de antes (ver
			// search_deadline.go): no se pierde ninguna fuente que antes llegara,
			// y el canal se cierra en cuanto todas responden en vez de esperar
			// siempre al temporizador.
			res := conTimeoutProveedor(searchGlobalTimeout, func() resultadoItems {
				items, fallo := searchProviderItems(p, query, perSource, searchType)
				return resultadoItems{items: items, fallo: fallo}
			})
			registrarProveedorStream(gen, p.Name(), res.valor.fallo || !res.ok)
			if len(res.valor.items) > 0 {
				ch <- namedBatch{name: p.Name(), items: res.valor.items}
			}
		}(p)
	}
	go func() { wg.Wait(); close(ch) }()

	// Red de seguridad (ver search_deadline.go): con el techo por proveedor el
	// canal se cierra solo en cuanto todos responden o expiran.
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
