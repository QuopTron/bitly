package gobackend

import (
	"encoding/json"
)

// appendSearchStream deduplicates and appends items to the stream buffer.
func anexarSearchStream(gen int64, items []FeedItemGo) {
	currentSearchStream.mu.Lock()
	defer currentSearchStream.mu.Unlock()
	if currentSearchStream.generation != gen {
		return // search was superseded by a new query
	}
	for _, item := range items {
		if esItemBusquedaDuplicado(currentSearchStream.items, item) {
			continue
		}
		currentSearchStream.items = append(currentSearchStream.items, item)
	}
	// Con el lote nuevo adentro, se completa el ISRC que faltaba usando el que
	// otra extensión ya trajo para el mismo track. Se hace acá, sobre TODO el
	// buffer, porque el ISRC puede llegar después del primer lote (cada fuente
	// responde a su ritmo) y también al revés: los que llegaron antes sin ISRC
	// se completan con el lote que acaba de entrar. Flutter relee la lista
	// entera en cada consulta, así que el ISRC completado llega a la UI.
	propagarISRC(currentSearchStream.items)
}

// isDuplicateSearchItem checks if an item already exists in the list.
//
// Para tracks la comparación es por identidad (ver search_identidad.go): ISRC
// cuando lo hay en los dos lados, y si no nombre+artista normalizados con
// chequeo de duración. Antes el respaldo era una comparación LITERAL de
// nombre y artista, y por eso el mismo tema aparecía varias veces en "Todas"
// (cada extensión lo escribe distinto) — y encima el que llegaba sin ISRC
// nunca se deduplicaba contra el que sí lo tenía.
//
// Para colecciones: dedup por type+id.
func esItemBusquedaDuplicado(existing []FeedItemGo, item FeedItemGo) bool {
	if item.Type == "track" {
		for _, e := range existing {
			if e.Type == "track" && esElMismoTrack(e, item) {
				return true
			}
		}
		return false
	}
	// Albums/artists/playlists: dedup by type+id
	for _, e := range existing {
		if e.Type == item.Type && e.ID == item.ID {
			return true
		}
	}
	return false
}

// GetSearchStreamResults returns the accumulated results for the current
// streaming search. Flutter polls this every ~500ms.
// Response: { items: [...], done: bool, generation: int64 }
func GetSearchStreamResults() string {
	currentSearchStream.mu.Lock()
	gen := currentSearchStream.generation
	items := make([]FeedItemGo, len(currentSearchStream.items))
	copy(items, currentSearchStream.items)
	done := currentSearchStream.done
	currentSearchStream.mu.Unlock()

	data, _ := json.Marshal(map[string]interface{}{
		"items":      items,
		"done":       done,
		"generation": gen,
	})
	return string(data)
}
