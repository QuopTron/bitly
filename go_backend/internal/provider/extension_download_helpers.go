package provider

import (
	"fmt"
)

func (p *ExtensionProvider) buscarTracksComoAlbums(query string, limit int) ([]AlbumResult, error) {
	result, err := p.callOp("search", "searchTracks", query, limit)
	if err != nil || result == nil {
		return nil, nil
	}
	return convertirAAlbumResults(result, p.name)
}

func (p *ExtensionProvider) buscarPorISRC(isrc string) (*TrackResult, error) {
	result, err := p.call("searchTracks", `isrc:"`+isrc+`"`, 5)
	if err != nil || result == nil {
		return nil, nil
	}
	tracks, err := convertirATrackResults(result, p.name)
	if err != nil || len(tracks) == 0 {
		return nil, nil
	}
	return &tracks[0], nil
}

// IsNumericID reports whether [id] is a plain numeric id (deezer/tidal track
// ids). Used to feed a feed item's TrackID back as the cross-provider id for
// providers (e.g. amazon) that resolve via it.
func IsNumericID(id string) bool {
	if id == "" || len(id) > 20 {
		return false
	}
	for i := 0; i < len(id); i++ {
		if id[i] < '0' || id[i] > '9' {
			return false
		}
	}
	return true
}

// IsSpotifyID reports whether [id] looks like a Spotify track id (22 base-62
// alphanumeric characters). Used to feed a feed item's TrackID back as the
// cross-provider spotify id for providers (e.g. amazon) that resolve via it.
func IsSpotifyID(id string) bool {
	if len(id) != 22 {
		return false
	}
	for i := 0; i < len(id); i++ {
		c := id[i]
		if !(c >= 'A' && c <= 'Z') && !(c >= 'a' && c <= 'z') && !(c >= '0' && c <= '9') {
			return false
		}
	}
	return true
}

// CheckAvailability invokes the extension's checkAvailability(isrc, trackName,
// artistName, {spotify_id, deezer_id, tidal_id, qobuz_id, duration_ms}) JS
// function, which returns {available, track_id} when the track can be resolved
// on the provider (e.g. amazon resolves the ASIN via its signed /resolve route
// or SongLink instead of an anonymous web search). All cross-provider ids are
// passed so any feed (spotify/deezer/tidal/qobuz/apple) can resolve — mirroring
// el reference middleware's CheckAvailabilityForItemID inputs. Returns the// provider-specific track id and whether it was found.
func (p *ExtensionProvider) CheckAvailability(isrc, trackName, artistName string, spotifyID, deezerID, tidalID, qobuzID string, durationMS int) (string, bool) {
	result, err := p.call("checkAvailability", isrc, trackName, artistName, map[string]interface{}{
		"spotify_id":  spotifyID,
		"deezer_id":   deezerID,
		"tidal_id":    tidalID,
		"qobuz_id":    qobuzID,
		"duration_ms": durationMS,
	})
	if err != nil || result == nil {
		return "", false
	}
	m, ok := result.(map[string]interface{})
	if !ok {
		return "", false
	}
	if avail, ok := m["available"].(bool); ok && !avail {
		return "", false
	}
	if id, ok := m["track_id"].(string); ok && id != "" {
		return id, true
	}
	return "", false
}

func (p *ExtensionProvider) llamarMetodoString(method string, args ...interface{}) (string, error) {
	result, err := p.call(method, args...)
	if err != nil {
		return "", err
	}
	if result == nil {
		return "", nil
	}
	if s, ok := result.(string); ok {
		return s, nil
	}
	return fmt.Sprint(result), nil
}
