// ─────────────────────────────────────────────────────────────
// rescue_identidad.go — Resolución del stream por IDENTIDAD EXACTA.
//
// Qué problema resuelve: la grabación pedida se identifica con ISRC y/o ids
// cross-proveedor (spotify/deezer/tidal/qobuz). Cada fuente tiene su PROPIA
// forma de pasar de esa identidad a un id suyo:
//
//   - Las extensiones exponen `checkAvailability(isrc, título, artista, ids)`.
//     Es la vía que traduce la identidad a un id streameable sin buscar por
//     nombre: YTMusic, por ejemplo, resuelve el ISRC al video de YouTube Music
//     verificado por duración+título+artista — el audio que SÍ existe.
//   - El resto (catálogos nativos y flac-rescue) se resuelven con
//     `GetTrackByISRC`.
//
// Antes la fase exacta del rescate solo probaba `GetTrackByISRC`, así que en la
// práctica únicamente flac-rescue podía contestar por ISRC: un track cuya
// identidad se derivó en vuelo (YouTube/SoundCloud, sin ISRC propio) se quedaba
// fuera de la fuente que mejor lo tiene. Este archivo centraliza la resolución
// para que TODA fuente que sepa resolver la identidad pueda aportar el stream, y
// para que el rescate por id (rescue_api.go) y el rescate por ISRC
// (rescue_stream.go) usen exactamente la misma regla.
//
// Nunca se streamea un candidato sin verificar cuando se conoce el título/artista
// pedido: una extensión cuya búsqueda cae a nombre (re-subidas de SoundCloud)
// devolvería una canción distinta.
//
// Se conecta con: rescue_stream.go (fase 1) y rescue_api.go
// (rescuePorIdentificadores). Parte del flujo: cadena de rescate de audio.
// ─────────────────────────────────────────────────────────────

package streaming

import "github.com/zarz/bitly/go_backend/internal/provider"

// datosIdentidad agrupa los identificadores con los que una fuente puede
// resolver la grabación EXACTA sin buscar por nombre. Cualquiera de ellos puede
// venir vacío; `tieneResolucion` decide si vale la pena sondear una fuente.
type datosIdentidad struct {
	isrc       string
	spotifyID  string
	deezerID   string
	tidalID    string
	qobuzID    string
	title      string
	artist     string
	durationMS int
}

// tieneResolucion reporta si hay algún identificador exacto que una fuente pueda
// traducir a un id propio. Sin ninguno, sondear solo gastaría un turno.
func (d datosIdentidad) tieneResolucion() bool {
	return d.isrc != "" || d.spotifyID != "" || d.deezerID != "" || d.tidalID != "" || d.qobuzID != ""
}

// identidadDeTrack arma la identidad desde el track del pedido, completando
// título/artista con los del llamador cuando el track no los trae.
func identidadDeTrack(track *provider.TrackResult, trackName, artistName string) datosIdentidad {
	d := datosIdentidad{title: trackName, artist: artistName}
	if track == nil {
		return d
	}
	d.isrc = track.ISRC
	d.spotifyID = track.SpotifyID
	d.deezerID = track.DeezerID
	d.tidalID = track.TidalID
	d.qobuzID = track.QobuzID
	d.durationMS = track.Duration
	if d.title == "" {
		d.title = track.Title
	}
	if d.artist == "" {
		d.artist = track.Artist
	}
	return d
}

// resolverStreamPorIdentidad intenta resolver el stream EXACTO de [p] a partir
// de la identidad [d]: primero `checkAvailability` —la vía de las extensiones
// para traducir ISRC/ids a su propio id—, después la búsqueda por ISRC del
// proveedor, y siempre con verificación contra el título/artista pedidos y la
// cascada de calidades de rescueProviderUnaVez.
//
// Devuelve (url, verificado) con el mismo contrato de las carreras: verified=true
// significa que la fuente TIENE la grabación pero necesita su sesión firmada.
func resolverStreamPorIdentidad(p provider.Provider, quality string, d datosIdentidad) (string, bool) {
	if !d.tieneResolucion() {
		return "", false
	}
	resolvedID := ""
	if ep, ok := p.(*provider.ExtensionProvider); ok {
		// La duración del pedido se pasa a propósito: la extensión la usa para
		// puntuar su candidato (no para rechazar), así que mejora la elección sin
		// volverla estricta.
		if id, found := ep.CheckAvailability(d.isrc, d.title, d.artist, d.spotifyID, d.deezerID, d.tidalID, d.qobuzID, d.durationMS); found && id != "" {
			resolvedID = id
		}
	}
	if resolvedID == "" && d.isrc != "" {
		if t, err := p.GetTrackByISRC(d.isrc); err == nil && t != nil && t.ID != "" {
			resolvedID = t.ID
		}
	}
	if resolvedID == "" {
		return "", false
	}
	// Mismo guard que el resto del camino: nunca streamear un candidato sin
	// verificar cuando conocemos el título/artista pedido. Una extensión cuya
	// búsqueda ISRC cae a una búsqueda por nombre (re-subidas de SoundCloud,
	// mapeos erróneos) serviría una canción distinta.
	if d.title != "" && verificarMatchStream(p, resolvedID, d.title, d.artist, d.isrc, true, d.durationMS) == "" {
		return "", false
	}
	return rescueProviderUnaVez(p, resolvedID, quality)
}
