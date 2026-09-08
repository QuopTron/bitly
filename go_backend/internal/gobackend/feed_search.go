package gobackend

import (
	"encoding/json"
	"strings"
)

// Search acepta un unico payload JSON desde Flutter (el dispatch de Kotlin
// serializa el mapa completo de argumentos como una cadena JSON). El payload
// se analiza internamente.
func Search(payload string) string {
	if reg == nil {
		return `[]`
	}

	var params struct {
		Query  string `json:"query"`
		Limit  int    `json:"limit"`
		Source string `json:"source"`
		Type   string `json:"type"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `[]`
	}

	query := params.Query
	limit := params.Limit
	if limit < 1 {
		limit = 20
	}
	source := params.Source
	searchType := params.Type

	// Si se buscan todos los proveedores, usar searchAll (en paralelo con 15s de timeout)
	if source == "" {
		return searchAllSource(query, limit, searchType)
	}

	// Specific source: find the provider and search it directly
	p := reg.Get(source)
	if p == nil {
		for _, name := range reg.Names() {
			if strings.EqualFold(name, source) {
				p = reg.Get(name)
				break
			}
		}
	}
	if p == nil {
		return `[]`
	}

	return searchProvider(p, query, limit, searchType)
}
