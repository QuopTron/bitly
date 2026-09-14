package streaming

import (
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// ─────────────────────────────────────────────────────────────────────────
// ISRC POR IDENTIDAD, NO POR NOMBRE (el eslabón que faltaba en la reproducción)
//
// Por qué el ISRC no puede salir de todas las fuentes por igual: el ISRC es un
// código de la GRABACIÓN, y solo lo publican los catálogos que lo licencian
// (Deezer, Qobuz, Tidal, Apple, Spotify, Amazon, MusicBrainz). Las fuentes que
// la app usa para conseguir el audio lossless cuando no hay sesión —YouTube
// Music, SoundCloud, Internet Archive, Soulseek— NO tienen ISRC: YouTube
// identifica por id de video, SoundCloud por id de track, Internet Archive por
// identificador de item y Soulseek literalmente no transporta el campo en su
// protocolo. No es que la app "no lo busque": ahí no existe.
//
// Entonces el ISRC no se saca de esas fuentes, se TRADUCE desde ellas. Hay dos
// caminos, y el orden importa:
//
//  1. POR IDENTIDAD (esto): el hook enrichTrack() de la propia extensión
//     (ytmusic-spotiflac lo implementa sobre SongLink/Odesli) recibe el id del
//     video y devuelve el ISRC + los ids cross-proveedor de esa misma grabación.
//     Es una traducción EXACTA de identificador a identificador: no adivina.
//  2. POR BÚSQUEDA VERIFICADA (provider.DerivarISRC): si la extensión no expone
//     el hook o no encuentra la canción, se busca título+artista en los
//     catálogos que publican ISRC y se exige original + duración compatible. Es
//     heurística, por eso va después.
//
// Sin el paso 1, un track de YouTube entraba a la reproducción SIN ISRC aunque
// la grabación tuviera uno: se perdía la fase exacta por ISRC y el rescate FLAC
// quedaba fuera de juego, dejándolo en el stream lossy por nombre. El pipeline
// de DESCARGA ya hacía esto (download/orchestrator_enrich.go); este archivo le
// da la misma capacidad a la REPRODUCCIÓN, y el resultado se guarda en la caché
// de metadata (play_metacache.go), así que se paga una vez por canción.
// ─────────────────────────────────────────────────────────────────────────

// enriquecerPorIdentidad consulta el hook enrichTrack() de la extensión que
// aportó el track. Devuelve nil cuando el proveedor no lo implementa (el caso
// de todos los catálogos, que ya traen el ISRC en su metadata) o cuando el
// enriquecimiento falla — nunca es fatal.
func enriquecerPorIdentidad(reg *provider.Registry, providerName, trackID, trackName string) *provider.EnrichTrackResult {
	if reg == nil || providerName == "" || trackID == "" {
		return nil
	}
	ep, ok := reg.Get(providerName).(*provider.ExtensionProvider)
	if !ok {
		return nil
	}
	// El pipeline de descarga manda el id tal cual llega de la UI, así que ese
	// es el primer intento (es el que está probado contra la extensión real).
	if en := ep.EnrichTrack(map[string]interface{}{"id": trackID, "name": trackName}); en != nil {
		return en
	}
	// La UI puede mandar el id con prefijo de fuente ("ytmusic-spotiflac:abc").
	// El hook espera el id pelado, así que se reintenta una vez sin el prefijo.
	if limpio := quitarPrefijoConocido(trackID); limpio != trackID {
		if en := ep.EnrichTrack(map[string]interface{}{"id": limpio, "name": trackName}); en != nil {
			return en
		}
	}
	return nil
}

// aplicarEnriquecimiento vuelca el ISRC y los ids cross-proveedor que resolvió
// la extensión sobre [t], SIN pisar nada que ya estuviera resuelto: lo que trae
// la fuente original tiene prioridad sobre la traducción.
func aplicarEnriquecimiento(t *provider.TrackResult, e *provider.EnrichTrackResult) {
	if t == nil || e == nil {
		return
	}
	if t.ISRC == "" {
		t.ISRC = e.ISRC
	}
	if t.DeezerID == "" {
		t.DeezerID = e.DeezerID
	}
	if t.TidalID == "" {
		t.TidalID = e.TidalID
	}
	if t.QobuzID == "" {
		t.QobuzID = e.QobuzID
	}
	if t.SpotifyID == "" {
		t.SpotifyID = e.SpotifyID
	}
}

// enriquecimientoVacio dice si el resultado del hook no aporta nada útil (así
// no se guarda una copia de la metadata para vender lo mismo).
func enriquecimientoVacio(e *provider.EnrichTrackResult) bool {
	if e == nil {
		return true
	}
	return strings.TrimSpace(e.ISRC) == "" &&
		strings.TrimSpace(e.DeezerID) == "" &&
		strings.TrimSpace(e.TidalID) == "" &&
		strings.TrimSpace(e.QobuzID) == "" &&
		strings.TrimSpace(e.SpotifyID) == ""
}
