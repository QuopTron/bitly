package provider

type CombinedResult struct {
	ID          string
	Type        string
	Name        string
	Artists     string
	CoverURL    string
	AlbumID     string
	AlbumName   string
	Duration    int
	ReleaseDate string
	TotalTracks int
	Owner       string
	ISRC        string
	SpotifyID   string
	DeezerID    string
	TidalID     string
	QobuzID     string
}

// CombinedSearch runs the extension's customSearch with no type filter, which
// Devuelve cada resultado kind (canciones, álbumes, artistas, listas de reproducción) en un único// call — the SpotiFLAC principle. Each item keeps its own item_type, so the UI
// can group them afterwards. Providers whose filtered per-type search returns
// empty (e.g. Spotify web search only populates the combined "all" view) rely
// on this to surface artists/albums/playlists at all.
//
// Unlike the per-type helpers, a transport failure (callOp error) is propagated
// so callers can distinguish "the source is down" from "no results" and avoid
// re-running doomed queries.
func (p *ExtensionProvider) CombinedSearch(query string, limit int) ([]CombinedResult, error) {
	opts := map[string]interface{}{"limit": limit}
	result, err := p.callOp("search", "customSearch", query, opts)
	if err != nil {
		return nil, err
	}
	if result == nil {
		return nil, nil
	}
	return p.combinadosDesdeResultado(result)
}

// SearchFiltered runs customSearch restricted to a single category using the
// extension's own manifest filter id (e.g. "tracks", "songs", "albums"). This is
// how SpotiFLAC re-queries a category when the user taps its bubble, returning
// many more results than the capped "all" mix (50 tracks / 20 albums, etc.).
//
// A transport failure es propagated (sin collapsed en "vacío"): un unhealthy// source (auth/session/rate-limit failure mid-search) must fail fast instead of
// making the caller fall through to more full queries that will fail the same
// way.
func (p *ExtensionProvider) SearchFiltered(filter string, query string, limit int) ([]CombinedResult, error) {
	opts := map[string]interface{}{"limit": limit, "filter": filter}
	result, err := p.callOp("search", "customSearch", query, opts)
	if err != nil {
		return nil, err
	}
	if result == nil {
		return nil, nil
	}
	return p.combinadosDesdeResultado(result)
}

func (p *ExtensionProvider) combinadosDesdeResultado(result interface{}) ([]CombinedResult, error) {
	list, ok := result.([]interface{})
	if !ok {
		return nil, nil
	}
	out := make([]CombinedResult, 0, len(list))
	for _, item := range list {
		m, ok := item.(map[string]interface{})
		if !ok {
			continue
		}
		typ := getString(m, "item_type", "type")
		id := quitarPrefijo(getString(m, "id"))
		if id == "" {
			continue
		}
		out = append(out, CombinedResult{
			ID:          id,
			Type:        typ,
			Name:        getString(m, "name", "title"),
			Artists:     getString(m, "artists", "artist"),
			CoverURL:    obtenerURLPortada(m),
			AlbumID:     getString(m, "album_id", "albumId", "albumID"),
			AlbumName:   getString(m, "album_name", "album"),
			Duration:    toInt(m["duration_ms"]),
			ReleaseDate: getString(m, "release_date"),
			TotalTracks: toInt(m["track_count"]),
			Owner:       getString(m, "owner"),
			ISRC:        getString(m, "isrc", "isrc_code"),
			SpotifyID:   getString(m, "spotify_id", "spotifyId"),
			DeezerID:    getString(m, "deezer_id", "deezerId"),
			TidalID:     getString(m, "tidal_id", "tidalId"),
			QobuzID:     getString(m, "qobuz_id", "qobuzId"),
		})
	}
	return out, nil
}

// GetTrack calls the extension's getTrack(id) JS function.
