package streaming

import (
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// rescueStream busca un stream URL en TODOS los providers que streamean.
// Los intentos por ISRC y por nombre corren en PARALELO entre providers con
// ventanas acotadas, de modo que un provider lento (captcha/sesión fría/429)
// ya no suma su tiempo a cada provider posterior — el más rápido gana en
// segundos en vez de arrastrar 60-100s como el walk serial anterior.
// [verified] reports that a provider HAS the exact track but needs its signed
// session to stream it — the caller fails fast on that verdict.
func rescueStream(reg *provider.Registry, track *provider.TrackResult, trackName, artistName, quality string) (url, prov string, attempted []string, verified bool) {
	names := ordenProvidersStreaming(reg)
	// Un proveedor que tiene la cancion exacta pero necesita su sesion
	// verificada se RECUERDA, nunca es fatal: la siguiente fase (busqueda por
	// nombre) aun puede encontrar la cancion en un proveedor que no indexa
	// ISRC (p. ej. youtube). El veredicto de verificacion solo se devuelve
	// cuando NINGUNA fase produjo un stream.
	var verifyName string

	// Phase 1: every provider resolves the same track via ISRC (exact match) in
	// parallel. Fast ~1-2s when the exact source is up; bounded so a provider
	// with a cold session never blocks the others. A provider that HAS the
	// track but needs its session verified is remembered so the caller can
	// surface it IF nothing else streams.
	if track != nil && track.ISRC != "" {
		u, provName, v := carreraRescue(reg, names, 8*time.Second, 2, func(name string, p provider.Provider) (string, bool) {
			trackByISRC, err := p.GetTrackByISRC(track.ISRC)
			if err != nil || trackByISRC == nil || trackByISRC.ID == "" {
				return "", false
			}
			// Even an ISRC-resolved candidate is verified against the queried
			// title/artist when we have them: an extension whose ISRC search
			// silently falls back to a name search (e.g. SoundCloud re-uploads
			// or a wrong mapping) must never serve an unrelated song.
			if trackName != "" && verificarMatchStream(p, trackByISRC.ID, trackName, artistName, track.ISRC, true) == "" {
				return "", false
			}
			return rescueProviderUnaVez(p, trackByISRC.ID, quality)
		})
		if v && verifyName == "" {
			verifyName = provName
		}
		if u != "" {
			return u, provName, nil, false
		}
		attempted = append(attempted, names...)
	}

	// Phase 2: strict original-track name search across providers, also in
	// parallel (the same rankedMatches filter used before, so a wrong/similar
	// upload is never served). A strict match whose stream needs verification
	// is remembered the same way — never fatal while another phase may stream.
	if trackName != "" && artistName != "" {
		u, provName, v := carreraRescue(reg, names, 10*time.Second, 2, func(name string, p provider.Provider) (string, bool) {
			results, err := p.SearchTracks(trackName+" "+artistName, 8)
			if err != nil || len(results) == 0 {
				return "", false
			}
			var sawVerify bool
			for _, cand := range matchesRankeados(trackName, artistName, results) {
				candURL, cv := rescueProviderUnaVez(p, cand.ID, quality)
				if cv {
					sawVerify = true
					continue
				}
				if candURL != "" {
					return candURL, false
				}
			}
			if sawVerify {
				return "", true
			}
			return "", false
		})
		if v && verifyName == "" {
			verifyName = provName
		}
		if u != "" {
			return u, provName, nil, false
		}
		attempted = append(attempted, names...)
	}
	if verifyName != "" {
		return "", verifyName, attempted, true
	}
	return "", "", attempted, false
}
