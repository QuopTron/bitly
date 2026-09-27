package provider

import "testing"

// extension_shapes_test.go — Conformidad del normalizador contra los shapes
// REALES de las nueve extensiones. Cada caso es cómo esa extensión escribe el
// mismo track (string vs arreglo vs objeto, ms vs segundos, isrc vs isrc_code,
// album string vs objeto). El normalizador tiene que sacar de todas el mismo
// TrackResult: ese es el punto de "parsear entre todas las extensiones".
func TestNormalizarShapesDeLasNueve(t *testing.T) {
	const album = "NO ME ARREPIENTO DE SENTIR TANTO"
	shapes := map[string]map[string]interface{}{
		"amazon": {
			"name": "BbY WOW", "artists": "KAROL G, Judeline & rusowsky",
			"album_name": album, "duration_ms": 225000.0,
		},
		"apple-music": {
			"name": "BbY WOW", "artists": []interface{}{"KAROL G", "Judeline", "rusowsky"},
			"album_name": album, "duration_ms": 225000.0,
		},
		"deezer": {
			"name": "BbY WOW", "artist": "KAROL G",
			"album":    map[string]interface{}{"title": album},
			"duration": 225.0, "isrc": "USUG12607940",
		},
		"pandora": {
			"name": "BbY WOW", "artists": "KAROL G",
			"album_name": album, "duration": 225.0, "isrc_code": "usug12607940",
		},
		"qobuz-web": {
			"title": "BbY WOW", "artists": []interface{}{map[string]interface{}{"name": "KAROL G"}},
			"album_name": album, "duration_ms": 225000.0,
		},
		"soundcloud": {
			"title": "BbY WOW", "artist": "KAROL G",
			"album_name": album, "duration_ms": 225000.0,
		},
		"spotify-web": {
			"name": "BbY WOW", "artists": []interface{}{"KAROL G, Judeline & rusowsky"},
			"album_name": album, "duration_ms": 225000.0,
		},
		"tidal-web": {
			"name": "BbY WOW", "artists": "KAROL G, Judeline & rusowsky",
			"album_name": album, "duration_ms": 225000.0,
		},
		"ytmusic": {
			"title": "BbY WOW", "artists": "KAROL G, Judeline & rusowsky",
			"album": album, "duration_ms": 225000.0,
		},
	}

	if len(shapes) != 9 {
		t.Fatalf("se esperaban 9 extensiones, hay %d", len(shapes))
	}
	for ext, m := range shapes {
		got := TrackResult{
			Title:    TextoDeCampo(m, "name", "title"),
			Artist:   TextoDeCampo(m, "artists", "artist", "album_artist"),
			Album:    TextoDeCampo(m, "album_name", "album_title", "albumName", "album"),
			Duration: DuracionDeCampo(m, "duration_ms", "durationMs", "duration"),
			ISRC:     ISRCDeCampo(m),
		}
		if got.Title != "BbY WOW" {
			t.Errorf("%s: título = %q", ext, got.Title)
		}
		if got.Artist == "" {
			t.Errorf("%s: artista vacío (shape no entendido)", ext)
		}
		if got.Album != album {
			t.Errorf("%s: álbum = %q, quería %q", ext, got.Album, album)
		}
		if got.Duration != 225000 {
			t.Errorf("%s: duración = %d, quería 225000", ext, got.Duration)
		}
		// Sólo las formas que declaran ISRC tienen que resolverlo; las otras lo
		// omiten a propósito (se deriva en vuelo).
		if m["isrc"] != nil || m["isrc_code"] != nil {
			if got.ISRC != "USUG12607940" {
				t.Errorf("%s: ISRC = %q", ext, got.ISRC)
			}
		}
	}
}
