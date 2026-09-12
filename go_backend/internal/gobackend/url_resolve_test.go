// url_resolve_test.go — Pruebas de la resolución de enlaces compartidos.
//
// Cubre las dos piezas puras del camino: elegir la extensión por patrón y
// normalizar la respuesta de handleUrl al formato ItemFeed que consume la app.
// Los formatos probados son los que devuelven realmente las extensiones
// (track envuelto, álbum con lista de tracks, y variantes sin envolver).
//
// Se conecta con: url_resolve.go + provider.ExtensionProvider.
// Parte del flujo: enlace compartido/pegado → ítem reproducible.
package gobackend

import (
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

func TestNormalizarEnlaceTrack(t *testing.T) {
	// Forma de spotify-web/ytmusic: {type:"track", track:{...}}.
	item := normalizarEnlaceAItem(map[string]interface{}{
		"success": true,
		"type":    "track",
		"track": map[string]interface{}{
			"id":          "4cOdK2wGLETKBW3PvgPWqT",
			"name":        "Never Gonna Give You Up",
			"artists":     "Rick Astley",
			"album_name":  "Whenever You Need Somebody",
			"duration_ms": 213573,
			"isrc":        "GBARL9300135",
			"cover_url":   "https://i.scdn.co/image/abc",
			"deezer_id":   "123456",
		},
	}, "spotify-web")

	if item == nil {
		t.Fatal("no normalizó un track válido")
	}
	if item["type"] != "track" || item["source"] != "spotify-web" {
		t.Errorf("tipo/fuente inesperados: %v / %v", item["type"], item["source"])
	}
	if item["id"] != "4cOdK2wGLETKBW3PvgPWqT" {
		t.Errorf("id = %v", item["id"])
	}
	if item["isrc"] != "GBARL9300135" {
		t.Errorf("isrc = %v (la descarga lo necesita para resolver en otras fuentes)", item["isrc"])
	}
	if item["duration_ms"] != 213573 {
		t.Errorf("duration_ms = %v", item["duration_ms"])
	}
	if item["deezer_id"] != "123456" {
		t.Errorf("deezer_id = %v (id cross-proveedor para el stream)", item["deezer_id"])
	}
}

func TestNormalizarEnlaceAlbumConTracks(t *testing.T) {
	// Forma de deezer: los campos del álbum arriba + lista de tracks.
	item := normalizarEnlaceAItem(map[string]interface{}{
		"type":      "album",
		"name":      "Whenever You Need Somebody",
		"cover_url": "https://e-cdns-images.dzcdn.net/cover",
		"album": map[string]interface{}{
			"id":           "119606",
			"name":         "Whenever You Need Somebody",
			"artists":      "Rick Astley",
			"total_tracks": 2,
		},
		"tracks": []interface{}{
			map[string]interface{}{"id": "t1", "name": "Never Gonna Give You Up", "artists": "Rick Astley", "isrc": "GBARL9300135", "duration_ms": 213573},
			map[string]interface{}{"id": "t2", "name": "Whenever You Need Somebody"},
		},
	}, "deezer")

	if item == nil {
		t.Fatal("no normalizó un álbum válido")
	}
	if item["type"] != "album" {
		t.Errorf("type = %v", item["type"])
	}
	if item["id"] != "119606" {
		t.Errorf("id = %v", item["id"])
	}
	if item["total_tracks"] != 2 {
		t.Errorf("total_tracks = %v", item["total_tracks"])
	}
	tracks, ok := item["tracks"].([]map[string]interface{})
	if !ok || len(tracks) != 2 {
		t.Fatalf("tracks = %#v, quiero 2 tracks", item["tracks"])
	}
	if tracks[0]["isrc"] != "GBARL9300135" || tracks[1]["name"] != "Whenever You Need Somebody" {
		t.Errorf("tracks mal normalizados: %#v", tracks)
	}
}

func TestNormalizarEnlaceAlbumDeAmazon(t *testing.T) {
	// Amazon devuelve los campos sueltos en la raíz, sin envolver por tipo.
	item := normalizarEnlaceAItem(map[string]interface{}{
		"type":      "album",
		"album":     map[string]interface{}{"id": "B01N4ND1T2", "name": "Album A", "artists": "Artista"},
		"name":      "Album A",
		"cover_url": "https://m.media-amazon.com/images/cover.jpg",
		"tracks":    []interface{}{map[string]interface{}{"id": "ASIN1", "name": "Tema 1"}},
	}, "amazon")

	if item == nil {
		t.Fatal("no normalizó el álbum de Amazon")
	}
	if item["id"] != "B01N4ND1T2" || item["cover_url"] != "https://m.media-amazon.com/images/cover.jpg" {
		t.Errorf("id/cover inesperados: %v / %v", item["id"], item["cover_url"])
	}
	if len(item["tracks"].([]map[string]interface{})) != 1 {
		t.Errorf("tracks = %v", item["tracks"])
	}
}

func TestNormalizarEnlaceSinDatosDevuelveNil(t *testing.T) {
	if item := normalizarEnlaceAItem(map[string]interface{}{"type": "track"}, "x"); item != nil {
		t.Errorf("un resultado vacío no debe producir ítem (got %#v)", item)
	}
	if item := normalizarEnlaceAItem(map[string]interface{}{}, "x"); item != nil {
		t.Errorf("un mapa vacío no debe producir ítem (got %#v)", item)
	}
}

// La extensión de YouTube responde el enlace con nombre "Loading..." y sin
// ISRC; esos son los ítems que hay que completar con getTrack.
func TestMetadataIncompleta(t *testing.T) {
	casos := []struct {
		nombre     string
		item       map[string]interface{}
		incompleta bool
	}{
		{
			"placeholder de YouTube",
			map[string]interface{}{"name": "Loading...", "type": "track"},
			true,
		},
		{
			"sin nombre",
			map[string]interface{}{"isrc": "GBARL9300135"},
			true,
		},
		{
			"completo",
			map[string]interface{}{"name": "Never Gonna Give You Up", "isrc": "GBARL9300135", "duration_ms": 213573},
			false,
		},
		{
			"nombre real pero sin isrc ni duración",
			map[string]interface{}{"name": "Tema"},
			true,
		},
	}
	for _, c := range casos {
		t.Run(c.nombre, func(t *testing.T) {
			if got := metadataIncompleta(c.item); got != c.incompleta {
				t.Errorf("metadataIncompleta(%v) = %v, quiero %v", c.item, got, c.incompleta)
			}
		})
	}
}

func TestCandidatosDeEnlaceEligenPorPatron(t *testing.T) {
	reg := provider.NewRegistry()
	vacia := provider.NewExtensionProvider("pandora", "pandora", nil)
	spotify := provider.NewExtensionProvider("spotify-web", "spotify-web", nil)
	spotify.SetURLPatterns([]string{"open.spotify.com", "spotify.com", "spotify:"})
	youtube := provider.NewExtensionProvider("ytmusic-spotiflac", "ytmusic-spotiflac", nil)
	youtube.SetURLPatterns([]string{"music.youtube.com", "youtu.be", "www.youtube.com/watch"})
	reg.Register(vacia)
	reg.Register(spotify)
	reg.Register(youtube)

	coinciden, resto := candidatosDeEnlace(reg, "https://open.spotify.com/track/abc")

	if len(coinciden) != 1 || coinciden[0].Name() != "spotify-web" {
		t.Fatalf("coinciden = %v, quiero sólo spotify-web", nombres(coinciden))
	}
	if len(resto) != 2 {
		t.Errorf("resto = %v, quiero las otras dos como respaldo", nombres(resto))
	}

	// Un enlace de YouTube elige la extensión de YouTube, no la de Spotify.
	coinciden, _ = candidatosDeEnlace(reg, "https://youtu.be/dQw4w9WgXcQ")
	if len(coinciden) != 1 || coinciden[0].Name() != "ytmusic-spotiflac" {
		t.Errorf("coinciden = %v, quiero ytmusic-spotiflac", nombres(coinciden))
	}
}

func nombres(ps []*provider.ExtensionProvider) []string {
	out := make([]string, 0, len(ps))
	for _, p := range ps {
		out = append(out, p.Name())
	}
	return out
}
