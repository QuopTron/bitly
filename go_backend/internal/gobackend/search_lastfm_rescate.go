package gobackend

import (
	"log"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider/lastfm"
)

// ─────────────────────────────────────────────────────────────
// search_lastfm_rescate.go — Last.fm como RED DE IDENTIDAD de la búsqueda.
//
// Last.fm NO es una fuente que se le ofrezca al usuario (ver
// search_fuentes.go): no entrega audio ni ISRC. Entra por detrás, cuando las
// extensiones NO DEVOLVIERON NINGUNA CANCIÓN, y aporta lo que sí tiene: el
// nombre CANÓNICO de la pista y el video OFICIAL que publicó el propio
// artista.
//
// Por qué esto arregla "la búsqueda no encuentra canciones": el caso real no
// era que las extensiones devolvieran poco, sino que lo que devolvían no
// pasaba el filtro de originales (nombre escrito distinto, remix, versión
// subida) y la lista de temas quedaba vacía. Con el nombre canónico y el id
// del video oficial, esa canción entra por el camino que el usuario ya pidió
// —el audio sale de YouTube, sí o sí— y además se reproduce sin búsqueda por
// nombre, que es lo que más tarda y más se equivoca.
//
// Costo: UNA consulta al sitio, cacheada 12 h y con el cliente en pausa (1
// petición cada 3 s). Solo corre cuando la alternativa es una pantalla vacía,
// nunca en el camino que ya funcionó.
// ─────────────────────────────────────────────────────────────

// maxRescateLastfm es cuántas pistas se agregan como máximo. Son el arranque,
// no el catálogo: si el usuario quiere más, toca el artista o el álbum.
const maxRescateLastfm = 5

// reforzarBusquedaConLastfm agrega pistas canónicas al buffer si la búsqueda
// terminó SIN NINGUNA canción. No hace nada si ya hay temas.
func reforzarBusquedaConLastfm(gen int64, query, source, searchType string) {
	if strings.TrimSpace(query) == "" || len([]rune(query)) < 3 {
		return
	}
	// Solo en "Todas": si el usuario eligió una fuente, devolverle resultados de
	// otra sin decirle nada sería engañoso.
	if strings.TrimSpace(source) != "" {
		return
	}
	if !tipoBuscaCanciones(searchType) {
		return
	}
	if bufferTieneCanciones() {
		return
	}
	pistas, err := lastfm.Compartido().Buscar(query)
	if err != nil {
		log.Printf("[lastfm] búsqueda sin identidad para %q: %v", query, err)
		return
	}
	items := itemsDePistasCanonicas(pistas)
	if len(items) == 0 {
		return
	}
	log.Printf("[lastfm] búsqueda %q sin canciones: %d pistas canónicas de YouTube", query, len(items))
	anexarSearchStream(gen, items)
}

// itemsDePistasCanonicas convierte pistas del sitio en items de búsqueda.
//
// Dos reglas: sin video oficial no entra (el audio sale de YouTube, sí o sí,
// así que una pista sin video no se puede reproducir) y el id lleva el prefijo
// "yt:" del proveedor nativo, que es lo que permite resolverlo sin búsqueda por
// nombre. Los que no tengan 11 caracteres de id se descartan: un id mal armado
// solo puede terminar en un stream de otra canción.
func itemsDePistasCanonicas(pistas []lastfm.Pista) []FeedItemGo {
	items := make([]FeedItemGo, 0, maxRescateLastfm)
	for _, p := range pistas {
		if p.Nombre == "" || len(p.YouTubeID) != 11 {
			continue
		}
		items = append(items, FeedItemGo{
			ID:         "yt:" + p.YouTubeID,
			Type:       "track",
			Name:       p.Nombre,
			Artists:    p.Artistas,
			DurationMs: p.DuracionMs,
			Source:     "youtube",
		})
		if len(items) == maxRescateLastfm {
			break
		}
	}
	return items
}

// tipoBuscaCanciones dice si el tipo pedido incluye canciones (es el único
// caso en el que tiene sentido rescatar temas concretos).
func tipoBuscaCanciones(searchType string) bool {
	switch strings.ToLower(strings.TrimSpace(searchType)) {
	case "", "all", "track", "tracks", "song", "songs":
		return true
	}
	return false
}

// bufferTieneCanciones informa si la búsqueda en curso ya tiene algún tema.
func bufferTieneCanciones() bool {
	currentSearchStream.mu.Lock()
	defer currentSearchStream.mu.Unlock()
	for _, item := range currentSearchStream.items {
		if item.Type == "track" {
			return true
		}
	}
	return false
}
