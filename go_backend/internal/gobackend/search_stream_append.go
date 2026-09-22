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
	agregados := false
	for _, item := range items {
		if esItemBusquedaDuplicado(currentSearchStream.items, item) {
			continue
		}
		currentSearchStream.items = append(currentSearchStream.items, item)
		agregados = true
	}
	// Con el lote nuevo adentro, se completa el ISRC que faltaba usando el que
	// otra extensión ya trajo para el mismo track. Se hace acá, sobre TODO el
	// buffer, porque el ISRC puede llegar después del primer lote (cada fuente
	// responde a su ritmo) y también al revés: los que llegaron antes sin ISRC
	// se completan con el lote que acaba de entrar. Flutter relee la lista
	// entera en cada consulta, así que el ISRC completado llega a la UI.
	//
	// Se aprovecha para saber si algo cambió de verdad: solo entonces hay que
	// tirar la respuesta serializada (ver jsonCache).
	if propagarISRC(currentSearchStream.items) {
		agregados = true
	}
	if agregados {
		currentSearchStream.jsonCache = ""
	}
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

// registrarProveedorStream anota cómo le fue a UNA fuente en la sesión de
// búsqueda actual: `fallo` true cuando no dio respuesta válida (error de
// transporte/sesión, cooldown o techo de tiempo vencido).
//
// Solo cuenta para la generación vigente: si la búsqueda ya fue reemplazada por
// otra consulta, esta anotación no le pertenece a nadie y se descarta (mismo
// criterio que anexarSearchStream).
func registrarProveedorStream(gen int64, fuente string, fallo bool) {
	if fuente == "" {
		return
	}
	currentSearchStream.mu.Lock()
	defer currentSearchStream.mu.Unlock()
	if currentSearchStream.generation != gen {
		return
	}
	if fallo {
		for _, f := range currentSearchStream.fallidas {
			if f == fuente {
				return // ya anotada (no puede contar dos veces)
			}
		}
		currentSearchStream.fallidas = append(currentSearchStream.fallidas, fuente)
	} else {
		currentSearchStream.fuentesOk++
	}
	// El estado por fuente viaja en la respuesta: la cadena cacheada ya no vale.
	currentSearchStream.jsonCache = ""
}

// GetSearchStreamResults returns the accumulated results for the current
// streaming search. Flutter polls this every ~80ms.
// Response: { items: [...], done: bool, generation: int64,
//
//	fallidas: [...], fuentes_ok: int }
//
// `fallidas` + `fuentes_ok` existen para que la app distinga "las fuentes
// contestaron y ninguna tenía nada" de "no se pudo preguntar": con la lista
// vacía y fuentes_ok == 0, mostrar "sin resultados" sería mentirle al usuario.
//
// Si nada cambió desde el sondeo anterior se devuelve la misma cadena ya
// serializada: la copia de la lista y el json.Marshal de todos los items eran
// trabajo repetido en el bucle más caliente de la búsqueda (ver jsonCache).
func GetSearchStreamResults() string {
	currentSearchStream.mu.Lock()
	if cached := currentSearchStream.jsonCache; cached != "" {
		currentSearchStream.mu.Unlock()
		return cached
	}
	gen := currentSearchStream.generation
	items := make([]FeedItemGo, len(currentSearchStream.items))
	copy(items, currentSearchStream.items)
	done := currentSearchStream.done
	// Normalizado a [] para que el contrato no mande `null` (Flutter lo lee
	// como lista vacía, pero un `null` explícito ya rompió contratos antes).
	fallidas := make([]string, len(currentSearchStream.fallidas))
	copy(fallidas, currentSearchStream.fallidas)
	data, err := json.Marshal(map[string]interface{}{
		"items":      items,
		"done":       done,
		"generation": gen,
		"fallidas":   fallidas,
		"fuentes_ok": currentSearchStream.fuentesOk,
	})
	if err != nil {
		currentSearchStream.mu.Unlock()
		return `{"items":[],"done":false,"generation":0,"fallidas":[],"fuentes_ok":0}`
	}
	// Se guarda bajo el mismo lock con el que se leyó el estado: si el buffer
	// cambió mientras se serializaba, la próxima llamada ya lo verá con el
	// jsonCache vacío y volverá a construirlo.
	currentSearchStream.jsonCache = string(data)
	currentSearchStream.mu.Unlock()
	return string(data)
}
