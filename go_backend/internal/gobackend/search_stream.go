package gobackend

import (
	"encoding/json"
	"sync"
	"time"
)

const searchGlobalTimeout = 4 * time.Second

// =========================================================================
// STREAMING SEARCH BUFFER
// =========================================================================

// searchStreamState holds partial results for a streaming search session.
// Flutter polls GetSearchStreamResults() to receive results incrementally
// as each provider completes, instead of waiting for the full 9s timeout.
type searchStreamState struct {
	mu         sync.Mutex
	items      []FeedItemGo
	done       bool
	generation int64

	// fallidas: fuentes que NO dieron una respuesta válida en esta búsqueda
	// (error de transporte/sesión, cooldown que evitó preguntar, o techo de
	// tiempo vencido). fuentesOk: las que sí contestaron, aunque fuera con cero
	// resultados. Van separadas para que la app no tenga que adivinar: con la
	// lista de items vacía, `fuentesOk` dice si alguna fuente llegó a hablar.
	// Sin esto, un fallo se pintaba como "sin resultados".
	fallidas  []string
	fuentesOk int

	// jsonCache es la respuesta ya serializada que se entregó la última vez.
	//
	// Flutter sondea GetSearchStreamResults cada 80 ms durante toda la ventana
	// de búsqueda (~160 sondeos), y el camino viejo copiaba TODA la lista y la
	// volvía a serializar en cada uno — aunque no hubiera llegado nada nuevo.
	// Con ~112 items por búsqueda eso es medio megabyte de JSON construido al
	// vacío por consulta. Se invalida (queda "") en cuanto cambia algo de
	// verdad: items, `done` o la generación.
	jsonCache string
}

var currentSearchStream = &searchStreamState{}

// SearchStream starts a parallel search across all providers and returns
// immediately. Results accumulate in a buffer that Flutter reads via
// GetSearchStreamResults(). Returns the generation ID for this search.
func SearchStream(payload string) string {
	if reg == nil {
		return `{"error":"no inicializado"}`
	}

	var params struct {
		Query  string `json:"query"`
		Limit  int    `json:"limit"`
		Source string `json:"source"`
		Type   string `json:"type"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}

	query := params.Query
	limit := params.Limit
	if limit < 1 {
		limit = 20
	}
	source := params.Source
	searchType := params.Type

	currentSearchStream.mu.Lock()
	currentSearchStream.generation++
	gen := currentSearchStream.generation
	currentSearchStream.items = nil
	currentSearchStream.done = false
	currentSearchStream.fallidas = nil
	currentSearchStream.fuentesOk = 0
	currentSearchStream.jsonCache = "" // búsqueda nueva: la respuesta vieja no sirve
	currentSearchStream.mu.Unlock()

	go runSearchStream(gen, query, limit, source, searchType)

	data, _ := json.Marshal(map[string]interface{}{
		"generation": gen,
	})
	return string(data)
}
