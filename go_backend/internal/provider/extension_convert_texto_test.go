package provider

import (
	"encoding/json"
	"testing"
)

// extension_convert_texto_test.go — El normalizador que hace que las nueve
// extensiones se lean igual. Cada caso es una forma REAL que emite alguna:
// deezer manda `album` con el nombre, ytmusic `artists` como arreglo, apple
// publica `images` como arreglo de {url}, pandora la duración en segundos, y
// varias usan `isrc_code`.

func TestTextoDeCampoFormas(t *testing.T) {
	casos := []struct {
		nombre string
		m      map[string]interface{}
		keys   []string
		want   string
	}{
		{"string", map[string]interface{}{"artists": "KAROL G, Judeline"}, []string{"artists", "artist"}, "KAROL G, Judeline"},
		{"arreglo de strings", map[string]interface{}{"artists": []interface{}{"KAROL G", "rusowsky"}}, []string{"artists"}, "KAROL G, rusowsky"},
		{"arreglo de objetos", map[string]interface{}{"artists": []interface{}{map[string]interface{}{"name": "KAROL G"}, map[string]interface{}{"name": "rusowsky"}}}, []string{"artists"}, "KAROL G, rusowsky"},
		{"objeto", map[string]interface{}{"album": map[string]interface{}{"title": "NO ME ARREPIENTO"}}, []string{"album"}, "NO ME ARREPIENTO"},
		{"salta el vacío", map[string]interface{}{"artists": "", "artist": "KAROL G"}, []string{"artists", "artist"}, "KAROL G"},
		{"sin dato", map[string]interface{}{}, []string{"artists"}, ""},
	}
	for _, c := range casos {
		if got := TextoDeCampo(c.m, c.keys...); got != c.want {
			t.Errorf("%s: TextoDeCampo = %q, quería %q", c.nombre, got, c.want)
		}
	}
}

func TestDuracionDeCampoFormas(t *testing.T) {
	casos := []struct {
		valor interface{}
		want  int
	}{
		{225000.0, 225000},   // duration_ms
		{225.0, 225000},      // duration en segundos
		{"225", 225000},      // string en segundos
		{"3:45", 225000},     // M:SS
		{"1:02:03", 3723000}, // H:MM:SS
		{0.0, 0},
		{"", 0},
	}
	for _, c := range casos {
		if got := DuracionDeCampo(map[string]interface{}{"duration": c.valor}, "duration"); got != c.want {
			t.Errorf("DuracionDeCampo(%v) = %d, quería %d", c.valor, got, c.want)
		}
	}
	// duration_ms manda sobre duration.
	if got := DuracionDeCampo(map[string]interface{}{"duration_ms": 225000.0, "duration": 1.0}, "duration_ms", "duration"); got != 225000 {
		t.Errorf("duration_ms ignorado: %d", got)
	}
}

func TestISRCDeCampoAliases(t *testing.T) {
	for _, m := range []map[string]interface{}{
		{"isrc": "usug12607940"},
		{"isrc_code": "USUG12607940"},
		{"isrcCode": "usug12607940"},
	} {
		if got := ISRCDeCampo(m); got != "USUG12607940" {
			t.Errorf("ISRCDeCampo(%v) = %q", m, got)
		}
	}
}

func TestPortadaDeCampoFormas(t *testing.T) {
	casos := []struct {
		m    map[string]interface{}
		want string
	}{
		{map[string]interface{}{"cover_url": "https://x/a.jpg"}, "https://x/a.jpg"},
		{map[string]interface{}{"images": []interface{}{map[string]interface{}{"url": "https://x/b.jpg"}}}, "https://x/b.jpg"},
		{map[string]interface{}{"image": map[string]interface{}{"src": "https://x/c.jpg"}}, "https://x/c.jpg"},
		{map[string]interface{}{"picture_xl": "https://x/d.jpg"}, "https://x/d.jpg"},
		{map[string]interface{}{}, ""},
	}
	for _, c := range casos {
		if got := PortadaDeCampo(c.m); got != c.want {
			t.Errorf("PortadaDeCampo(%v) = %q, quería %q", c.m, got, c.want)
		}
	}
}

// TestHomeFeedItemAceptaShapesDeCadaExtension: un ítem de feed con `artists` en
// arreglo o `album` en objeto hacía fallar el json.Unmarshal ENTERO (campo
// string con arreglo) y la fuente quedaba sin feed. Ahora se normaliza.
func TestHomeFeedItemAceptaShapesDeCadaExtension(t *testing.T) {
	crudo := `{
		"name": "BbY WOW",
		"artists": [{"name": "KAROL G"}, {"name": "rusowsky"}],
		"album": {"title": "NO ME ARREPIENTO DE SENTIR TANTO"},
		"duration": "3:45",
		"isrc_code": "usug12607940",
		"images": [{"url": "https://x/c.jpg"}],
		"id": "B0HL1XPQR8",
		"type": "track"
	}`
	var item HomeFeedItem
	if err := json.Unmarshal([]byte(crudo), &item); err != nil {
		t.Fatalf("unmarshal falló: %v", err)
	}
	if item.Name != "BbY WOW" || item.Artists != "KAROL G, rusowsky" {
		t.Errorf("nombre/artistas mal: %q / %q", item.Name, item.Artists)
	}
	if item.AlbumName != "NO ME ARREPIENTO DE SENTIR TANTO" {
		t.Errorf("álbum mal: %q", item.AlbumName)
	}
	if item.DurationMs != 225000 {
		t.Errorf("duración mal: %d", item.DurationMs)
	}
	if item.ISRC != "USUG12607940" {
		t.Errorf("isrc mal: %q", item.ISRC)
	}
	if item.ThumbURL != "https://x/c.jpg" {
		t.Errorf("portada mal: %q", item.ThumbURL)
	}
	if item.ItemType != "track" {
		t.Errorf("tipo mal: %q", item.ItemType)
	}
}
