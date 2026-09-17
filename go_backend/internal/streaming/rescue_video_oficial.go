package streaming

import (
	"log"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
	"github.com/zarz/bitly/go_backend/internal/provider/lastfm"
)

// ─────────────────────────────────────────────────────────────
// rescue_video_oficial.go — Fase del VIDEO OFICIAL dentro del rescate
// de stream.
//
// Qué problema resuelve: la causa más común de "no hay stream" es que la
// búsqueda POR NOMBRE no confirma la canción (la encuentra escrita distinto,
// la confunde con un remix o no la encuentra). Acá se le pregunta a Last.fm
// cuál es el video que publicó el PROPIO ARTISTA para esa pista y se pide el
// audio por ESE id: el proveedor de YouTube lo resuelve directo, sin buscar
// nada, así que llega en segundos y nunca trae otra canción. La coincidencia
// ya viene verificada por Last.fm (nombre normalizado igual y, cuando hay,
// duración dentro de la tolerancia).
//
// Corre EN PARALELO con las otras fases y con una gracia acotada, así que
// cuando el camino normal resolvió no retrasa nada (su resultado se
// descarta). Last.fm va con caché de 12 h y una petición cada 3 s: el costo
// real en los temas ya vistos es cero.
// ─────────────────────────────────────────────────────────────

// esperaVideoOficial es lo que se aguarda por esta fase al final del rescate
// (solo cuando NINGUNA otra fase consiguió audio). Cubre la pausa del cliente
// de Last.fm con margen para su petición.
const esperaVideoOficial = 3 * time.Second

// faseVideoOficial devuelve (url, proveedor) del video OFICIAL de la pista, o
// vacío cuando Last.fm no tiene identidad fiable para ella.
//
// El proveedor nativo de YouTube recibe el id con su prefijo ("yt:<id>"), que
// es el único que acepta un video suelto.
func faseVideoOficial(
	reg *provider.Registry,
	track *provider.TrackResult,
	trackName, artistName, quality string,
) (string, string) {
	if reg == nil || trackName == "" || artistName == "" {
		return "", ""
	}
	p := reg.Get("youtube")
	if p == nil {
		// Una extensión lo reemplazó: no acepta el id "yt:" tal cual, así que
		// esta fase no aplica (la búsqueda por nombre ya lo cubre).
		return "", ""
	}
	album, durMs := "", 0
	if track != nil {
		album, durMs = track.Album, track.Duration
	}
	pista, err := lastfm.Compartido().MejorCoincidencia(artistName, album, trackName, durMs)
	if err != nil {
		log.Printf("[rescue] video oficial: sin identidad para %q: %v", trackName, err)
		return "", ""
	}
	if pista == nil || pista.YouTubeID == "" {
		return "", ""
	}
	log.Printf("[rescue] video oficial (lastfm): %s — %s", pista.Nombre, pista.YouTubeID)
	url, _ := rescueProviderUnaVez(p, "yt:"+pista.YouTubeID, quality)
	if url == "" {
		return "", ""
	}
	return url, p.Name()
}
