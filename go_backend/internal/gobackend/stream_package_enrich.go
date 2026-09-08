package gobackend

import (
	"github.com/zarz/bitly/go_backend/internal/download"
)

// streamEnrichISRC completa el ISRC faltante desde el proveedor fuente o los
// ids cross-provider para que la descarga de respaldo coincida estrictamente
// (nunca servir un remix del mismo titulo si se conoce el ISRC exacto; los
// feeds suelen entregar isrc=null). Solo corre en reproduccion real (AllowFallback=true)
// despues de que la ruta rapida de streaming fallo, evitando el costo de
// hasta 7 llamadas GetTrack secuenciales que antes demoraban el primer tap.
func streamEnrichISRC(params *streamPackageParams) {
	if params.ISRC != "" {
		return
	}
	enrich := func(pn string, id string) {
		if params.ISRC != "" || id == "" {
			return
		}
		// spotify-web can only resolve native Spotify IDs; feeding it a
		// deezer/tidal prefixed id ("deezer:3733293352") throws inside the
		// extension and wastes an API call.
		if pn == "spotify-web" && !download.IsSpotifyTrackID(id) {
			return
		}
		if p := reg.Get(pn); p != nil {
			if t, err := p.GetTrack(id); err == nil && t != nil && t.ISRC != "" {
				params.ISRC = t.ISRC
			}
		}
	}
	// Only the calls that can actually succeed: the source provider with its
	// OWN id, and spotify-web with a native Spotify id (its metadata carries
	// ISRC reliably). Cross-feeding another provider's id into the source
	// provider's GetTrack is a no-op that just burns latency.
	enrich(params.PreferredProvider, params.TrackID)
	enrich("spotify-web", params.SpotifyID)
	enrich("spotify-web", params.TrackID)
}
