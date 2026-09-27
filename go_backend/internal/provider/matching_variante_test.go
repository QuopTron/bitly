package provider

import "testing"

// matching_variante_test.go — La versión no original puede estar marcada en el
// título, en el artista o en el álbum (cada extensión la pone donde la tiene).
// IsNonOriginalTrack tiene que ver los TRES, sin castigar a un artista cuyo
// nombre legítimo coincide con un marcador cuando el pedido también lo trae.

func TestIsNonOriginalTrackCampos(t *testing.T) {
	query := "BbY WOW"
	artista := "KAROL G, Judeline & rusowsky"
	casos := []struct {
		nombre string
		t      TrackResult
		want   bool
	}{
		{"corte real", TrackResult{Title: "BbY WOW", Artist: "KAROL G", Album: "NO ME ARREPIENTO DE SENTIR TANTO"}, false},
		{"marcador en el título", TrackResult{Title: "BbY WOW (Remix)", Artist: "Alguien"}, true},
		{"marcador en el artista", TrackResult{Title: "BbY WOW", Artist: "Slowed Sounds"}, true},
		{"marcador en el artista (orquesta)", TrackResult{Title: "BbY WOW", Artist: "Epic Symphonic Orchestra"}, true},
		{"marcador en el álbum", TrackResult{Title: "BbY WOW", Artist: "KAROL G", Album: "Live at Wembley"}, true},
	}
	for _, c := range casos {
		if got := IsNonOriginalTrack(c.t, query, artista); got != c.want {
			t.Errorf("%s: IsNonOriginalTrack = %v, quería %v", c.nombre, got, c.want)
		}
	}
}

// La banda "Live" no puede quedar marcada como versión en vivo cuando el pedido
// busca justamente a "Live": el marcador solo cuenta si la consulta no lo trae.
func TestIsNonOriginalTrackNoCastigaArtistaHomonimo(t *testing.T) {
	banda := TrackResult{Title: "Overcome", Artist: "Live"}
	if IsNonOriginalTrack(banda, "Overcome", "Live") {
		t.Error("la banda Live quedó marcada como versión no original")
	}
}
