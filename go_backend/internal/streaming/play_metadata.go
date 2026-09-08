package streaming

import (
	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

func obtenerMetadata(reg *provider.Registry, providerName, trackID, trackName, artistName, isrc, spotifyID, deezerID, tidalID, qobuzID string) *provider.TrackResult {
	cacheKey := claveCacheMetadata(isrc, spotifyID, deezerID, tidalID, qobuzID, trackID, trackName, artistName)
	// Session cache: the same track is resolved many times (feed prefetch,
	// queue neighbours, re-tap). Serve the cached result instead of re-searching.
	if cached := metadataCacheada(cacheKey); cached != nil {
		return cached
	}

	store := func(t *provider.TrackResult) *provider.TrackResult {
		guardarMetadata(cacheKey, t)
		// Also index by the found track's ISRC so later calls that only carry a
		// different provider id still hit (their key normalizes to the ISRC).
		if t != nil && t.ISRC != "" {
			guardarMetadata(claveCacheMetadata(t.ISRC, "", "", "", "", "", "", ""), t)
		}
		return t
	}

	exactID := quitarPrefijoConocido(trackID)
	if providerName != "" {
		p := reg.Get(providerName)
		if p != nil && !cooldown.IsCooled(providerName) {
			// Exact ISRC first — one call, no name search, and the result is the
			// canonical identity every provider can resolve against.
			if isrc != "" {
				if track, err := p.GetTrackByISRC(isrc); err == nil && track != nil {
					return store(track)
				}
			}
			if exactID != "" {
				if track, err := p.GetTrack(exactID); err == nil && track != nil {
					return store(track)
				}
			}
			// Cross-provider ids via the provider that owns them (only the
			// matching shape is fed, so no wasted calls).
			for _, cid := range []struct {
				name string
				id   string
			}{{"spotify", spotifyID}, {"deezer", deezerID}, {"tidal", tidalID}, {"qobuz", qobuzID}} {
				if cid.id == "" || cid.name == providerName {
					continue
				}
				if t, err := p.GetTrack(cid.id); err == nil && t != nil {
					return store(t)
				}
			}
			if trackName != "" && artistName != "" {
				if results, err := p.SearchTracks(trackName+" "+artistName, 8); err == nil && len(results) > 0 {
					if best := provider.BestOriginal(trackName, artistName, results); best != nil {
						return store(best)
					}
				}
			}
		}
	}

	// No exact id on the preferred provider: try the ISRC on the OTHER
	// streaming providers (each may know it natively), skipping cooled ones.
	if isrc != "" {
		for _, name := range streamingProviders {
			if name == providerName {
				continue
			}
			p := reg.Get(name)
			if p == nil || cooldown.IsCooled(name) {
				continue
			}
			if track, err := p.GetTrackByISRC(isrc); err == nil && track != nil {
				return store(track)
			}
		}
	}

	// Last resort — bounded name search across healthy providers, only when no
	// identifier exists to resolve exactly.
	if trackName != "" && artistName != "" {
		for _, name := range streamingProviders {
			if name == providerName {
				continue
			}
			p := reg.Get(name)
			if p == nil || cooldown.IsCooled(name) {
				continue
			}
			if results, err := p.SearchTracks(trackName+" "+artistName, 8); err == nil && len(results) > 0 {
				if best := provider.BestOriginal(trackName, artistName, results); best != nil {
					return store(best)
				}
			}
		}
	}
	return nil
}
