// Puente de RESOLUCIÓN DE ENLACES hacia Flutter.
//
// Qué hace: recibe un enlace de música (Spotify, YouTube Music, Deezer, Tidal,
// Qobuz, Amazon, Apple, SoundCloud, Pandora) y devuelve el ítem ya normalizado
// al formato ItemFeed que consume la app, con sus tracks cuando es álbum o
// playlist.
//
// Cómo elige la fuente: cada extensión declara en su manifest (urlHandler
// .patterns) qué hosts sabe resolver; se prueban primero esas y, si ninguna
// coincide, se prueba al resto como respaldo. La extensión elegida resuelve el
// enlace con su función handleUrl(url).
//
// Por qué existe: las extensiones siempre supieron resolver enlaces, pero el
// backend nunca las llamaba — compartir o pegar un enlace de Spotify/YouTube
// no hacía nada.
//
// Se conecta con: provider.ExtensionProvider.HandleUrl + el puente RPC
// (bridge_rpc.go en móvil, cmd/server en escritorio) y la app Flutter.
package gobackend

import (
	"encoding/json"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// ResolveUrl resuelve un enlace de música. Payload: {"url": "https://..."}.
// Devuelve un ItemFeed JSON (con "tracks" si es álbum/playlist) o {"error":...}.
func ResolveUrl(payload string) string {
	var params struct {
		URL string `json:"url"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return jsonError(err)
	}
	enlace := strings.TrimSpace(params.URL)
	if enlace == "" {
		return jsonErrorString("url vacía")
	}
	if reg == nil {
		return jsonErrorString("no inicializado")
	}

	coinciden, resto := candidatosDeEnlace(reg, enlace)
	for _, ep := range append(coinciden, resto...) {
		m, err := ep.HandleUrl(enlace)
		if err != nil || m == nil {
			continue
		}
		item := normalizarEnlaceAItem(m, ep.Name())
		if item == nil {
			continue
		}
		completarTrackSiFalta(item, ep)
		data, _ := json.Marshal(item)
		return string(data)
	}
	return jsonErrorString("ninguna fuente pudo resolver el enlace")
}

// candidatosDeEnlace separa las extensiones que declaran ese enlace en su
// urlHandler (van primero) del resto (respaldo). Sin este orden se llamaría a
// las nueve extensiones por cada enlace, con la latencia que eso implica.
func candidatosDeEnlace(reg *provider.Registry, enlace string) (coinciden, resto []*provider.ExtensionProvider) {
	if reg == nil {
		return nil, nil
	}
	for _, p := range reg.All() {
		ep, ok := p.(*provider.ExtensionProvider)
		if !ok {
			continue
		}
		if ep.PuedeResolverURL(enlace) {
			coinciden = append(coinciden, ep)
		} else {
			resto = append(resto, ep)
		}
	}
	return coinciden, resto
}

// completarTrackSiFalta completa la metadata de un track resuelto cuando la
// extensión responde con el mínimo (id) y deja el resto para después.
//
// Por qué: la extensión de YouTube devuelve el track con nombre "Loading..." y
// SIN ISRC (su handleUrl lanza la búsqueda en segundo plano y responde ya), así
// que el miniplayer mostraba "Loading..." y la descarga no tenía ISRC con el
// que encontrar el FLAC en otras fuentes. Con el id, getTrack ya devuelve el
// nombre, el artista, la carátula, el ISRC y los ids cross-proveedor.
func completarTrackSiFalta(item map[string]interface{}, ep *provider.ExtensionProvider) {
	if item["type"] != "track" {
		return
	}
	id, _ := item["id"].(string)
	if id == "" || !metadataIncompleta(item) {
		return
	}
	track, err := ep.GetTrack(id)
	if err != nil || track == nil || track.Title == "" {
		return
	}
	item["name"] = track.Title
	if track.Artist != "" {
		item["artists"] = track.Artist
	}
	if track.ISRC != "" {
		item["isrc"] = track.ISRC
	}
	if track.CoverURL != "" {
		item["cover_url"] = track.CoverURL
	}
	if track.Album != "" {
		item["album_name"] = track.Album
	}
	if track.AlbumID != "" {
		item["album_id"] = track.AlbumID
	}
	if track.Duration > 0 {
		item["duration_ms"] = track.Duration
	}
	for clave, valor := range map[string]string{
		"spotify_id": track.SpotifyID,
		"deezer_id":  track.DeezerID,
		"tidal_id":   track.TidalID,
		"qobuz_id":   track.QobuzID,
	} {
		if valor != "" {
			item[clave] = valor
		}
	}
}

// metadataIncompleta reporta si al ítem le falta lo mínimo para mostrarse y
// para que la descarga busque en otras fuentes (nombre real e ISRC).
func metadataIncompleta(item map[string]interface{}) bool {
	nombre, _ := item["name"].(string)
	sinNombre := nombre == "" || strings.EqualFold(nombre, "loading...")
	isrc, _ := item["isrc"].(string)
	dur, _ := item["duration_ms"].(int)
	return sinNombre || (isrc == "" && dur == 0)
}

// normalizarEnlaceAItem convierte la respuesta cruda de handleUrl al formato
// ItemFeed. Los campos se buscan primero en el objeto del tipo principal
// (track/album/artist/playlist) y luego arriba, porque las extensiones no
// usan todos el mismo nivel. Devuelve nil si no hay nada aprovechable.
func normalizarEnlaceAItem(m map[string]interface{}, proveedor string) map[string]interface{} {
	tipo := strings.ToLower(strings.TrimSpace(strOf(m, "type")))
	if tipo == "" {
		switch {
		case m["album"] != nil:
			tipo = "album"
		case m["artist"] != nil:
			tipo = "artist"
		default:
			tipo = "track"
		}
	}

	principal := mapaDe(m[tipo])
	if principal == nil {
		switch tipo {
		case "track":
			principal = mapaDe(m["track"])
		case "album":
			principal = mapaDe(m["album"])
		case "artist":
			principal = mapaDe(m["artist"])
		case "playlist":
			principal = mapaDe(m["playlist"])
		}
	}
	if principal == nil {
		principal = m // algunas extensiones ponen los campos en la raíz
	}

	campo := func(keys ...string) string {
		if s := strOf(principal, keys...); s != "" {
			return s
		}
		return strOf(m, keys...)
	}
	numero := func(keys ...string) int {
		if n := strInt(principal, keys...); n != 0 {
			return n
		}
		return strInt(m, keys...)
	}

	item := map[string]interface{}{
		"type":       tipo,
		"source":     proveedor,
		"id":         campo("id", "track_id", "trackId", "album_id", "artist_id"),
		"name":       campo("name", "title"),
		"artists":    campo("artists", "artist", "artist_name"),
		"cover_url":  campo("cover_url", "coverUrl", "cover", "images", "image_url"),
		"isrc":       campo("isrc"),
		"album_id":   campo("album_id", "albumId"),
		"album_name": campo("album_name", "album"),
		"spotify_id": campo("spotify_id", "spotifyId"),
		"deezer_id":  campo("deezer_id", "deezerId"),
		"tidal_id":   campo("tidal_id", "tidalId"),
		"qobuz_id":   campo("qobuz_id", "qobuzId"),
	}
	if ms := numero("duration_ms", "durationMs", "duration"); ms > 0 {
		item["duration_ms"] = ms
	}
	if total := numero("total_tracks", "totalTracks", "track_count"); total > 0 {
		item["total_tracks"] = total
	}
	if fecha := campo("release_date", "releaseDate"); fecha != "" {
		item["release_date"] = fecha
	}
	if dueno := campo("owner", "creator", "label"); dueno != "" {
		item["owner"] = dueno
	}

	if item["id"] == "" && item["name"] == "" {
		return nil
	}

	// Álbum/playlist/cualquier resultado con lista: se normalizan sus tracks
	// con el mismo formato, para que la app los recorra y los reproduzca.
	if tracks := tracksDeEnlace(m, principal); len(tracks) > 0 {
		item["tracks"] = tracks
	}
	return item
}

// tracksDeEnlace recoge la lista de tracks de un resultado de handleUrl,
// mirando el nivel superior y el objeto principal (álbum → album.tracks).
func tracksDeEnlace(m, principal map[string]interface{}) []map[string]interface{} {
	crudo := m["tracks"]
	if crudo == nil {
		crudo = principal["tracks"]
	}
	lista, ok := crudo.([]interface{})
	if !ok || len(lista) == 0 {
		return nil
	}
	tracks := make([]map[string]interface{}, 0, len(lista))
	for _, t := range lista {
		tm := mapaDe(t)
		if tm == nil {
			continue
		}
		if tm["id"] == nil && tm["track_id"] == nil && tm["name"] == nil {
			continue
		}
		tracks = append(tracks, map[string]interface{}{
			"type":        "track",
			"id":          strOf(tm, "id", "track_id", "trackId"),
			"name":        strOf(tm, "name", "title"),
			"artists":     strOf(tm, "artists", "artist", "artist_name"),
			"cover_url":   strOf(tm, "cover_url", "coverUrl", "cover", "images", "image_url"),
			"isrc":        strOf(tm, "isrc"),
			"album_id":    strOf(tm, "album_id", "albumId"),
			"album_name":  strOf(tm, "album_name", "album"),
			"duration_ms": strInt(tm, "duration_ms", "durationMs", "duration"),
		})
	}
	return tracks
}

// mapaDe convierte un valor JSON en mapa, o nil si no lo es.
func mapaDe(v interface{}) map[string]interface{} {
	if m, ok := v.(map[string]interface{}); ok {
		return m
	}
	return nil
}
