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
	// Un índice del buffer por lote: la deduplicación dejó de ser un barrido
	// contra todo lo ya recibido (O(n²) en pares y en normalizaciones de texto).
	// Ver search_stream_indice.go. Se arma por lote y no se guarda entre lotes:
	// así siempre describe el buffer tal como está —incluso después de que
	// propagarISRC() escriba sobre items ya guardados— y no deja estado que haya
	// que resetear con cada búsqueda.
	antes := len(currentSearchStream.items)
	ix := nuevoIndiceBusqueda(currentSearchStream.items)
	currentSearchStream.items = ix.agregar(currentSearchStream.items, items)
	agregados := len(currentSearchStream.items) > antes
	// Con el lote nuevo adentro, se completa el ISRC que faltaba usando el que
	// otra extensión ya trajo para el mismo track. Se hace acá, sobre TODO el
	// buffer, porque el ISRC puede llegar después del primer lote (cada fuente
	// responde a su ritmo) y también al revés: los que llegaron antes sin ISRC
	// se completan con el lote que acaba de entrar. Flutter relee la lista
	// entera en cada consulta, así que el ISRC completado llega a la UI.
	//
	// Se aprovecha para saber si algo cambió de verdad: solo entonces hay que
	// tirar la respuesta serializada (ver jsonCache).
	//
	// Se le pasa el índice de claves que acaba de armar el dedup: tiene
	// exactamente la misma forma (clave → posiciones) y volver a construirlo
	// sería normalizar dos veces el mismo lote. nil si nunca hizo falta.
	if propagarISRCCon(currentSearchStream.items, ix.porClave) {
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
	return posicionDuplicadoLineal(existing, item) >= 0
}

// posicionDuplicadoLineal devuelve la POSICIÓN del item dentro de `existing` si
// ya está (mismo criterio que describe esItemBusquedaDuplicado) o -1 si es
// nuevo.
//
// Es la versión de REFERENCIA, la del barrido lineal: en producción la reemplaza
// el índice (ver search_stream_indice.go), y existe para que los tests tengan
// contra qué compararlo. Devuelve la posición, y no un bool, porque quien
// descarta un duplicado necesita saber a quién fusionarle el ISRC (fusionarISRC).
func posicionDuplicadoLineal(existing []FeedItemGo, item FeedItemGo) int {
	if item.Type == "track" {
		for i, e := range existing {
			if e.Type == "track" && esElMismoTrack(e, item) {
				return i
			}
		}
		return -1
	}
	// Albums/artists/playlists: dedup by type+id
	for i, e := range existing {
		if e.Type == item.Type && e.ID == item.ID {
			return i
		}
	}
	return -1
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
