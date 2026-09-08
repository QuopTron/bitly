package gobackend

import (
	"encoding/json"
	"strings"
)

func GetTrack(payload string) string {
	if reg == nil {
		return `{"error":"no inicializado"}`
	}
	var params struct {
		ProviderName string `json:"providerName"`
		TrackID      string `json:"trackID"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	p := reg.Get(params.ProviderName)
	if p == nil {
		return jsonErrorString("proveedor no encontrado")
	}
	track, err := p.GetTrack(params.TrackID)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(track)
	return string(data)
}

func GetAlbum(payload string) string {
	if reg == nil {
		return `{"error":"no inicializado"}`
	}
	var params struct {
		ProviderName string `json:"providerName"`
		AlbumID      string `json:"albumID"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	p := reg.Get(params.ProviderName)
	if p == nil {
		return jsonErrorString("proveedor no encontrado")
	}
	album, err := p.GetAlbum(params.AlbumID)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(album)
	return string(data)
}

func GetArtist(payload string) string {
	if reg == nil {
		return `{"error":"no inicializado"}`
	}
	var params struct {
		ProviderName string `json:"providerName"`
		ArtistID     string `json:"artistID"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	p := reg.Get(params.ProviderName)
	if p == nil {
		return jsonErrorString("proveedor no encontrado")
	}
	artist, err := p.GetArtist(params.ArtistID)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(artist)
	return string(data)
}

func ResolveISRC(isrc string) string {
	if searchEngine == nil {
		return `{"error":"no inicializado"}`
	}
	results, err := searchEngine.SearchTracks(`isrc:"`+isrc+`"`, 5)
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(results)
	return string(data)
}

// splitSearchQuery analiza una consulta como "Artist - Title" o "Title ft Artist"
// en (titulo, artista). Cuando no hay separador, toda la consulta se trata como
// una busqueda solo-por-titulo con artista vacio.
func splitSearchQuery(q string) (string, string) {
	low := strings.ToLower(q)
	// "Artist - Title"
	if idx := strings.Index(low, " - "); idx > 0 {
		return strings.TrimSpace(q[idx+3:]), strings.TrimSpace(q[:idx])
	}
	// "Title by Artist"
	if idx := strings.Index(low, " by "); idx >= 0 {
		return strings.TrimSpace(q[:idx]), strings.TrimSpace(q[idx+4:])
	}
	// "Title ft Artist" / "Title feat Artist"
	for _, sep := range []string{" ft ", " feat ", " featuring ", " ft. ", " feat. "} {
		if idx := strings.Index(low, sep); idx >= 0 {
			return strings.TrimSpace(q[:idx]), strings.TrimSpace(q[idx+len(sep):])
		}
	}
	return q, ""
}
