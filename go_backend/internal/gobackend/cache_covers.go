package gobackend

import (
	"encoding/json"
	"os"
	"path/filepath"
)

// SetStreamCacheMaxMb sets the cache limit, capped by the user's plan.
func SetStreamCacheMaxMb(payload string) string {
	var params struct {
		MB int `json:"mb"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"ok":false,"error":"payload inválido"}`
	}
	limit := streamCacheLevelLimitMB()
	if params.MB > limit {
		params.MB = limit
	}
	setStreamCacheMaxMB(params.MB)
	out, _ := json.Marshal(map[string]interface{}{
		"mb":             params.MB,
		"level_limit_mb": limit,
		"ok":             true,
	})
	return string(out)
}

// GetCoverPathForTrack returns a local cover path if the cover is already cached.
func GetCoverPathForTrack(payload string) string {
	var params struct {
		TrackID   string `json:"track_id"`
		ISRC      string `json:"isrc"`
		TrackName string `json:"track_name"`
		Artist    string `json:"artist_name"`
		CoverURL  string `json:"cover_url"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return ""
	}
	// El mismo track se busca por caminos distintos: un like llega con el id de
	// la fuente y una descarga con el ISRC o el nombre. Se prueban todas las
	// claves conocidas — primero en el índice (lo que guardó cualquier camino)
	// y después por hash, que es como se nombran los archivos de SaveCover.
	var keys []string
	if params.ISRC != "" {
		keys = append(keys, params.ISRC)
	}
	if params.TrackID != "" {
		keys = append(keys, params.TrackID)
	}
	if params.CoverURL != "" {
		keys = append(keys, params.CoverURL)
	}
	if params.TrackName != "" {
		keys = append(keys, params.TrackName+"|"+params.Artist)
	}
	dir := rutaDirPortadas()
	for _, key := range keys {
		if nombre := buscarClavePortada(dir, key); nombre != "" {
			abs, _ := filepath.Abs(filepath.Join(dir, nombre))
			return abs
		}
	}
	for _, key := range keys {
		path := filepath.Join(dir, hashPortada(key)+".jpg")
		if _, err := os.Stat(path); err == nil {
			abs, _ := filepath.Abs(path)
			return abs
		}
	}
	return ""
}

// SaveCover downloads a cover image to the local covers dir and returns the
// absolute path of the saved file (empty string on failure). The absolute path
// is used directly by the UI as a local file path, so covers keep working on
// platforms without the desktop HTTP server (e.g. Android).
func SaveCover(payload string) string {
	var params struct {
		URL string `json:"url"`
		// Keys extra (isrc, id, "nombre|artista") para que OTROS caminos
		// encuentren esta misma carátula sin volver a bajarla.
		Keys []string `json:"keys"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil || params.URL == "" {
		return ""
	}
	dir := rutaDirPortadas()
	filename := hashPortada(params.URL) + ".jpg"
	path := filepath.Join(dir, filename)
	abs, _ := filepath.Abs(path)
	// Ya estaba en disco: se registran las claves nuevas y se devuelve.
	if _, err := os.Stat(path); err == nil {
		registrarClavesPortada(dir, append(params.Keys, params.URL), filename)
		return abs
	}
	if err := os.MkdirAll(dir, 0755); err != nil {
		return ""
	}

	data, err := descargarImagenPortada(params.URL)
	if err != nil {
		return ""
	}
	if err := os.WriteFile(path, data, 0644); err != nil {
		return ""
	}
	registrarClavesPortada(dir, append(params.Keys, params.URL), filename)
	// New cover on disk: enforce the covers cap (oldest first) so a big liked
	// library never fills the storage with portadas.
	evictarPortadas(dir)
	return abs
}

// DeleteCover removes a cached cover file.
func DeleteCover(payload string) string {
	var params struct {
		URL string `json:"url"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil || params.URL == "" {
		return `{"ok":false}`
	}
	filename := hashPortada(params.URL) + ".jpg"
	dir := rutaDirPortadas()
	os.Remove(filepath.Join(dir, filename))
	olvidarArchivoPortada(dir, filename)
	return `{"ok":true}`
}

// ResetDatabase resets in-memory state (Flutter persists Drift locally).
func ResetDatabase() string {
	setUserMode("")
	setDownloadDir("")
	setStreamCacheMaxMB(0)
	return `{"ok":true}`
}

// =========================================================================
// HELPERS
// =========================================================================
