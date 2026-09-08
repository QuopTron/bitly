package provider

type EnrichTrackResult struct {
	ISRC      string
	DeezerID  string
	TidalID   string
	QobuzID   string
	SpotifyID string
}

// EnrichTrack llama a la funcion JS enrichTrack(trackObj) de la extension, que
// resuelve ISRC e IDs cross-proveedor via Odesli/SongLink. El trackObj debe
// contener como minimo { id: "<video-id>" } para ytmusic-spotiflac. Devuelve
// nulo si la extension no exporta enrichTrack o si el enriquecimiento falla.
func (p *ExtensionProvider) EnrichTrack(trackObj map[string]interface{}) *EnrichTrackResult {
	if trackObj == nil || trackObj["id"] == nil {
		return nil
	}
	res, err := p.call("enrichTrack", trackObj)
	if err != nil || res == nil {
		return nil
	}
	m, ok := res.(map[string]interface{})
	if !ok {
		return nil
	}
	out := &EnrichTrackResult{
		ISRC:      getString(m, "isrc"),
		DeezerID:  getString(m, "deezer_id"),
		TidalID:   getString(m, "tidal_id"),
		QobuzID:   getString(m, "qobuz_id"),
		SpotifyID: getString(m, "spotify_id"),
	}
	if out.ISRC == "" && out.DeezerID == "" && out.TidalID == "" && out.QobuzID == "" && out.SpotifyID == "" {
		return nil
	}
	return out
}
