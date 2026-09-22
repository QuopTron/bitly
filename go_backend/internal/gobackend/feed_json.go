package gobackend

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

func combinadoAJSON(res []provider.CombinedResult, source string) string {
	return itemsAJSON(combinadosAFeedItems(res, source))
}

// itemsAJSON serializa una lista de items para las fronteras de la API (RPC,
// rutas del servidor).
//
// Existe para que el trabajo real viva en funciones que devuelven slices y
// SOLO las fronteras serialicen. Antes los caminos internos se pasaban los
// resultados como string JSON y el agregador los volvía a deserializar
// (`json.Unmarshal` de lo que acababa de `json.Marshal`ear el proveedor), así
// que cada búsqueda pagaba dos conversiones completas de todos los items por
// cada fuente: CPU y memoria tiradas a la basura sin cambiar una coma del
// resultado.
func itemsAJSON(items []FeedItemGo) string {
	// Un slice nil saldría como `null`, y el contrato con Flutter es `[]`: el
	// camino viejo siempre marshaleaba un slice vacío no-nil, así que este
	// refactor tiene que garantizar la misma forma de respuesta.
	if items == nil {
		return `[]`
	}
	data, _ := json.Marshal(items)
	return string(data)
}

// searchProviderAll performs a single combined search (unfiltered) for the
// provider. Extensions return every result kind with its own item_type, which
// is exactly how SpotiFLAC surfaces tracks/albums/artists/playlists together.
// If el combined call yields nothing (e.g. un non-extension proveedor), we fall// back to a plain track search so the source still returns something.
func searchProviderAll(p provider.Provider, query string, limit int) string {
	return itemsAJSON(searchProviderAllItems(p, query, limit))
}

// searchProviderAllItems es el trabajo real de searchProviderAll sin pasar por
// JSON (ver itemsAJSON).
func searchProviderAllItems(p provider.Provider, query string, limit int) []FeedItemGo {
	items := make([]FeedItemGo, 0)
	// Circuit breaker: skip only if cooled *for search* (not provider-wide,
	// which streaming/download errors trip and would empty this search).
	if cooldown.IsCooledOp(p.Name(), "search") {
		return items
	}
	if ep, ok := p.(*provider.ExtensionProvider); ok {
		if res, err := ep.CombinedSearch(query, limit); err == nil && len(res) > 0 {
			return combinadosAFeedItems(res, ep.Name())
		}
	}
	tracks, err := p.SearchTracks(query, limit)
	if err == nil {
		for _, t := range tracks {
			items = append(items, trackToFeedItem(t, p.Name()))
		}
	}
	return items
}
