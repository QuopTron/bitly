package download

import (
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// resolveProviderTrackID maps a track request to a provider-specific track id
// using the richest signal available, in order of strength:
//  1. the provider that OWNS the item id (source provider) uses req.TrackID directly;
//  2. any cross-provider id already known (spotify/deezer/tidal/qobuz) via GetTrack;
//  3. ISRC lookup (strong, unambiguous);
//  4. strict title+artist search, keeping only the original track.
func resolverTrackIDProvider(p provider.Provider, name string, req Request) (string, string, string) {
	title, artist := req.Title, req.Artist

	if name == req.Provider && req.TrackID != "" {
		// The owner proveedor receives su NATIVE id: feed items carry a
		// prefixed id ("tidal:123", "spotify:abc") that the extension's JS
		// does not understand. Mirror the reference middleware's
		// trimKnownProviderPrefix before handing it to the extension.
		return quitarPrefijoTrack(req.TrackID), title, artist
	}

	// Cross-provider ids: resolve them if the provider knows the id.
	for _, cid := range []string{req.SpotifyID, req.DeezerID, req.TidalID, req.QobuzID} {
		if cid == "" || strings.HasPrefix(cid, "deezer:") || strings.HasPrefix(cid, "spotify:") {
			continue
		}
		if t, err := p.GetTrack(cid); err == nil && t != nil {
			return t.ID, t.Title, t.Artist
		}
	}

	// Providers like amazon expose checkAvailability, which resolves the ASIN
	// via their signed /resolve route (using the verified session) or SongLink
	// instead of an anonymous web search that returns a login dialog -> zero
	// results. Prefer it before falling back to a name search.
	if ep, ok := p.(*provider.ExtensionProvider); ok {
		// Feed items don't always carry explicit cross-provider ids, but the
		// source provider's TrackID IS the native id for that source. Derive the
		// correct one so amazon can resolve via Deezer/Spotify/ISRC no matter
		// which feed produced the track (Spotify feed -> 22-char id, deezer feed
		// -> numeric id, tidal -> numeric id, amazon -> ASIN).
		spotifyID := req.SpotifyID
		deezerID := req.DeezerID
		tidalID := req.TidalID
		qobuzID := req.QobuzID
		// Feed items only carry the source provider's TrackID, but extensions
		// resolve via their own native id — so derive the right cross-provider
		// id from the TrackID shape (spotify=22 base62, deezer/tidal/qobuz=
		// numeric) so amazon & friends can resolve from ANY feed, exactly like
		// igual que el middleware de referencia deriva estos ids para CheckAvailability.
		switch {
		case req.Provider == "spotify" || req.Provider == "spotify-web":
			if spotifyID == "" && provider.IsSpotifyID(quitarPrefijoTrack(req.TrackID)) {
				spotifyID = quitarPrefijoTrack(req.TrackID)
			}
		case req.Provider == "deezer" || req.Provider == "deezer-web":
			if deezerID == "" && provider.IsNumericID(quitarPrefijoTrack(req.TrackID)) {
				deezerID = quitarPrefijoTrack(req.TrackID)
			}
		case req.Provider == "tidal" || req.Provider == "tidal-web":
			if tidalID == "" && provider.IsNumericID(quitarPrefijoTrack(req.TrackID)) {
				tidalID = quitarPrefijoTrack(req.TrackID)
			}
		case req.Provider == "qobuz" || req.Provider == "qobuz-web":
			if qobuzID == "" && provider.IsNumericID(quitarPrefijoTrack(req.TrackID)) {
				qobuzID = quitarPrefijoTrack(req.TrackID)
			}
		}
		if id, found := ep.CheckAvailability(req.ISRC, req.Title, req.Artist, spotifyID, deezerID, tidalID, qobuzID, req.DurationMS); found && id != "" {
			return id, title, artist
		}
		// amazon's anonymous name/ISRC search always returns a login dialog
		// (zero results) and is very slow, burning the RPC timeout before the
		// fallback reaches providers that actually yield a stream. If amazon
		// cannot resolve via its signed /resolve / SongLink route, bail out
		// immediately and let the next provider take over.
		if name == "amazon" {
			return "", title, artist
		}
	}

	if req.ISRC != "" {
		if t, err := p.GetTrackByISRC(req.ISRC); err == nil && t != nil {
			return t.ID, t.Title, t.Artist
		}
	}

	if title != "" {
		if results, err := p.SearchTracks(title+" "+artist, 8); err == nil && len(results) > 0 {
			// Only resolve the ORIGINAL track (strong artist + title, no
			// remix/live/cover variants) so a fallback never pulls a different song.
			if best := provider.BestOriginal(title, artist, results); best != nil {
				return best.ID, best.Title, best.Artist
			}
		}
	}

	return "", title, artist
}
