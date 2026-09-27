package download

import (
	"regexp"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// duracionCoincide es la regla de "dura lo mismo" para las descargas. La
// definición vive ahora en provider.DuracionCoincide, compartida con la
// verificación de reproducción (que antes no miraba la duración): una versión
// cover/remix/extendida/acústica de la "misma" canción casi siempre difiere
// más que la tolerancia de la versión de álbum, así que una duración rara es
// una señal fuerte de versión equivocada aunque título y artista coincidan.
func duracionCoincide(queryDurationMS, got int) bool {
	return provider.DuracionCoincide(queryDurationMS, got)
}

// confirmDownloadMatch reverse-verifies, before downloading, that a track id
// resolved for a NON-owner provider is the ORIGINAL requested track. It rejects
// only when we can CONFIRM it is a different song — an explicit ISRC mismatch
// or a weak title/artist match. A candidate with no ISRC at all (typical of
// soundcloud re-uploads) is NOT rejected, because soundcloud never exposes
// ISRC and rejecting it would make every soundcloud-only track unplayable;
// marked variants (remix/live/cover) are already filtered upstream by
// RankOriginalCandidates.
func confirmarMatchDescarga(p provider.Provider, trackID, isrc, queryTitle, queryArtist string, queryDurationMS int) bool {
	t, err := p.GetTrack(trackID)
	if err != nil || t == nil {
		return true
	}
	if isrc != "" && t.ISRC != "" && !strings.EqualFold(strings.ToUpper(isrc), strings.ToUpper(t.ISRC)) {
		return false
	}
	if !duracionCoincide(queryDurationMS, t.Duration) {
		return false
	}
	// Identidad EXACTA por ISRC, solo en proveedores que pueden dar fe de él (los
	// catálogos, cuyo ISRC viene del sello, y el rescate indexado por ISRC, cuyo
	// título ES el ISRC). Los re-subidos (YouTube / SoundCloud) infieren el ISRC
	// por nombre: ahí se sigue exigiendo título + artista (un remix con el mismo
	// título recibía el ISRC del original y se descargaba como si fuera la
	// canción pedida).
	if isrc != "" && provider.EsProveedorAutoritativoISRC(p.Name()) {
		mismoISRC := t.ISRC != "" && strings.EqualFold(strings.ToUpper(isrc), strings.ToUpper(t.ISRC))
		if mismoISRC || provider.EsCandidatoPorISRC(isrc, t) {
			return true
		}
	}
	if queryTitle == "" {
		return true
	}
	if _, ok := provider.OriginalStrength(queryTitle, queryArtist, *t); ok {
		return true
	}
	if t.ISRC != "" {
		if it, err := p.GetTrackByISRC(t.ISRC); err == nil && it != nil {
			if _, ok := provider.OriginalStrength(queryTitle, queryArtist, *it); ok {
				return true
			}
		}
	}
	return false
}

// stripTrackPrefix removes a KNOWN source prefix ("tidal:", "spotify:",
// "deezer:", "qobuz:", "amazon:", ...) from a feed item's id so provider
// GetTrack calls receive the raw native id the extension understands. Only
// known prefixes are stripped — a URL-shaped id ("https://...") or any other
// colon-bearing value is passed through untouched, mirroring the reference
// middleware's trimKnownProviderPrefix behavior.
func quitarPrefijoTrack(id string) string {
	return provider.TrimKnownProviderPrefix(id)
}

// spotifyTrackIDRe matches Spotify's canonical 22-char base62 track IDs.
var spotifyTrackIDRe = regexp.MustCompile(`^[0-9A-Za-z]{22}$`)

// IsSpotifyTrackID reports whether [id] (optionally with a provider prefix
// like "spotify:" or "deezer:") is a well-formed Spotify track ID. Used to
// skip wasted spotify-web getTrack calls when a cross-provider id belongs to
// another service (a deezer/tidal numeric id always throws "Invalid Spotify
// ID character" inside the extension and returns an empty track).
func IsSpotifyTrackID(id string) bool {
	return spotifyTrackIDRe.MatchString(quitarPrefijoTrack(strings.TrimSpace(id)))
}
