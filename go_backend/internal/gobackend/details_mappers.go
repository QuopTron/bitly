package gobackend

import "encoding/json"

// =========================================================================
// RAW → Flutter schema mappers (handles the various extension shapes)
// =========================================================================

func mapearAlbumDetalle(raw, source string) string {
	var m map[string]interface{}
	if err := json.Unmarshal([]byte(raw), &m); err != nil {
		return ""
	}
	name := stringDetalle(m, "name", "title")
	if name == "" {
		return ""
	}
	tracks := extraerTracksDetalle(m, source)
	out := map[string]interface{}{
		"id":          stringDetalle(m, "id"),
		"name":        name,
		"coverUrl":    portadaDetalle(m),
		"artistName":  stringDetalle(m, "artists", "artist", "artist_name"),
		"releaseDate": stringDetalle(m, "release_date", "releaseDate"),
		"albumType":   stringDetalle(m, "album_type", "albumType"),
		"totalTracks": intDetalle(m, "total_tracks", "totalTracks"),
		"tracks":      tracks,
	}
	data, _ := json.Marshal(out)
	return string(data)
}

func mapearPlaylistDetalle(raw, source string) string {
	var m map[string]interface{}
	if err := json.Unmarshal([]byte(raw), &m); err != nil {
		return ""
	}
	name := stringDetalle(m, "name", "title")
	if name == "" {
		return ""
	}
	tracks := extraerTracksDetalle(m, source)
	out := map[string]interface{}{
		"id":        stringDetalle(m, "id"),
		"name":      name,
		"coverUrl":  portadaDetalle(m),
		"itemCount": intDetalle(m, "total_tracks", "totalTracks", "track_count", "itemCount"),
		"tracks":    tracks,
	}
	data, _ := json.Marshal(out)
	return string(data)
}

func mapearArtistDetalle(raw, source string) string {
	var m map[string]interface{}
	if err := json.Unmarshal([]byte(raw), &m); err != nil {
		return ""
	}
	name := stringDetalle(m, "name", "title")
	if name == "" {
		return ""
	}
	topTracks := extraerTracksDetalle(m, source)
	albums := extraerAlbumesDetalle(m)
	out := map[string]interface{}{
		"id":        stringDetalle(m, "id"),
		"name":      name,
		"imageUrl":  portadaDetalle(m),
		"topTracks": topTracks,
		"topAlbums": albums,
	}
	data, _ := json.Marshal(out)
	return string(data)
}

// extractDetailTracks pulls a track list from any common key name. Artist
// responses commonly put top songs under top_tracks/topTracks (amazon,
