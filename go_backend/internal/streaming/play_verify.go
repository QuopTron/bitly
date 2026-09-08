package streaming

import (
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

func verificarMatchStream(p provider.Provider, id, queryTitle, queryArtist, isrc string, authoritative bool) string {
	if queryTitle == "" {
		return id
	}
	t, err := p.GetTrack(id)
	if err != nil || t == nil {
		// Can't fetch the record to verify: only an authoritative identifier is
		// trusted; a guessed id is refused rather than guessing a wrong song.
		if authoritative {
			return id
		}
		return ""
	}
	// ISRC mismatch is the strongest, cheapest mismatch signal: when both sides
	// carry an ISRC and they differ, it is definitely not the requested track.
	if isrc != "" && t.ISRC != "" && !strings.EqualFold(strings.ToUpper(isrc), strings.ToUpper(t.ISRC)) {
		return ""
	}
	if _, ok := provider.OriginalStrength(queryTitle, queryArtist, *t); ok {
		return id
	}
	// El propio registro del proveedor puede exponer un ISRC: re-resolver via la
	// ruta isrc del mismo proveedor es otra forma de confirmar la identidad.
	if t.ISRC != "" {
		if it, err := p.GetTrackByISRC(t.ISRC); err == nil && it != nil {
			if _, ok := provider.OriginalStrength(queryTitle, queryArtist, *it); ok {
				return id
			}
		}
	}
	return ""
}

// GetStreamPackage busca metadata + stream URL + letras en una sola llamada.
// [isrc] + cross-provider ids (spotify/deezer/tidal/qobuz) let the resolution
// identify the track EXACTLY (ISRC / CheckAvailability) instead of name-searching
// every provider — the single biggest driver of provider rate-limits (429) was
// repeated per-track name searches during prefetch/queue traversal.
