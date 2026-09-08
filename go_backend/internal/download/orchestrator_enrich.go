package download

import (
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// enrichISRC completa el ISRC del request cuando el item del feed no lo traía
// (ej. feeds de tidal/apple/qobuz, o tracks con isrc=null). Prueba primero el
// track del provider fuente y luego cada cross-provider id vía spotify (su
// metadata trae ISRC de forma confiable), para que un track llegado desde
// CUALQUIER feed tenga un ISRC estricto. Providers como amazon resuelven por
// SongLink usando el ISRC, así que se puede servir la misma fuente exacta en
// vez de caer a un remix lossy de mismo título en soundcloud/ytmusic.
func (o *Orchestrator) enrichISRC(req *Request) {
	if req.ISRC != "" {
		return
	}
	enrich := func(pn string, id string) {
		if req.ISRC != "" || id == "" || pn == "" {
			return
		}
		// spotify-web solo puede resolver IDs nativos de Spotify; darle un id
		// numérico de deezer/tidal desperdicia una llamada y devuelve vacío.
		if pn == "spotify-web" && !IsSpotifyTrackID(id) {
			return
		}
		if sp := o.providers.Get(pn); sp != nil {
			if t, err := sp.GetTrack(quitarPrefijoTrack(id)); err == nil && t != nil && t.ISRC != "" {
				req.ISRC = t.ISRC
			}
		}
	}
	// El lookup del track propio de cada provider es la fuente más confiable de
	// ISRC para su propio id (deezer/qobuz/tidal/spotify exponen isrc en GetTrack).
	enrich(req.Provider, req.TrackID)
	enrich("deezer", req.DeezerID)
	enrich("tidal", req.TidalID)
	enrich("qobuz", req.QobuzID)
	enrich("spotify-web", req.SpotifyID)
	enrich(req.Provider, req.SpotifyID)
	enrich("spotify-web", req.TrackID)

	// Último recurso: extensiones que no exponen getTrack (ej. ytmusic-spotiflac)
	// pueden tener enrichTrack(), que resuelve ISRC + cross-provider ids vía
	// Odesli/SongLink usando la URL de YouTube Music.
	if req.ISRC == "" {
		if sp := o.providers.Get(req.Provider); sp != nil {
			if ep, ok := sp.(*provider.ExtensionProvider); ok {
				enriched := ep.EnrichTrack(map[string]interface{}{
					"id":   req.TrackID,
					"name": req.Title,
				})
				if enriched != nil {
					if enriched.ISRC != "" {
						req.ISRC = enriched.ISRC
					}
					if enriched.DeezerID != "" && req.DeezerID == "" {
						req.DeezerID = enriched.DeezerID
					}
					if enriched.TidalID != "" && req.TidalID == "" {
						req.TidalID = enriched.TidalID
					}
					if enriched.QobuzID != "" && req.QobuzID == "" {
						req.QobuzID = enriched.QobuzID
					}
					if enriched.SpotifyID != "" && req.SpotifyID == "" {
						req.SpotifyID = enriched.SpotifyID
					}
				}
			}
		}
	}
}
