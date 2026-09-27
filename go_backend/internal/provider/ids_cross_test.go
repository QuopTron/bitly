// ids_cross_test.go — Reglas compartidas de ids cross-proveedor.
//
// Qué se cuida: la descarga y el streaming tienen que derivar EXACTAMENTE lo
// mismo a partir del `source` + `trackID` de un ítem de feed. Si divergen, un
// ítem de Tidal/Deezer/Qobuz/Spotify que sí rescata por identidad en la descarga
// cae a una búsqueda por nombre en el streaming (justo donde aparecen los
// re-subidos). Estos casos fijan la forma de cada id y, sobre todo, que una
// fuente que NO es catálogo no invente un id.
package provider

import "testing"

func TestTrimKnownProviderPrefix(t *testing.T) {
	casos := []struct{ in, esperado string }{
		{"tidal:123", "123"},
		{"spotify:6XbtvPmIpyCbjuT0e8cQtp", "6XbtvPmIpyCbjuT0e8cQtp"},
		{"qobuz-web:99", "99"}, // prefijo desconocido: intacto
		{"123", "123"},
		{"https://music.apple.com/x", "https://music.apple.com/x"}, // ":" de URL, no prefijo
		{"spotify:", "spotify:"},                                   // sin cuerpo, intacto
		{"", ""},
	}
	for _, c := range casos {
		if got := TrimKnownProviderPrefix(c.in); got != c.esperado {
			t.Errorf("TrimKnownProviderPrefix(%q) = %q, se esperaba %q", c.in, got, c.esperado)
		}
	}
}

func TestDerivarIDsCrossDesdeFuente(t *testing.T) {
	const spotify22 = "6XbtvPmIpyCbjuT0e8cQtp"

	casos := []struct {
		nombre                     string
		source, trackID            string
		sp, dz, td, qz             string
		espSP, espDZ, espTD, espQZ string
	}{
		{"spotify-web deriva el id de 22 del TrackID", "spotify-web", spotify22, "", "", "", "", spotify22, "", "", ""},
		{"deezer deriva el id numérico", "deezer", "3733293352", "", "", "", "", "", "3733293352", "", ""},
		{"tidal-web deriva el id numérico", "tidal-web", "123456", "", "", "", "", "", "", "123456", ""},
		{"qobuz-web deriva el id numérico", "qobuz-web", "98765", "", "", "", "", "", "", "", "98765"},
		{"id con prefijo se limpia antes de derivar", "tidal-web", "tidal:123456", "", "", "", "", "", "", "123456", ""},
		{"un id ya presente NO se pisa", "deezer", "111", "", "222", "", "", "", "222", "", ""},
		{"amazon (ASIN) no deriva nada", "amazon", "B0D9XYZ", "", "", "", "", "", "", "", ""},
		{"apple-music (numérico propio) NO deriva cross", "apple-music", "6814997425", "", "", "", "", "", "", "", ""},
		{"soundcloud numérico NO deriva cross", "soundcloud", "12345", "", "", "", "", "", "", "", ""},
		{"spotify con id que no tiene forma de Spotify no deriva", "spotify-web", "123", "", "", "", "", "", "", "", ""},
		{"TrackID vacío no deriva", "tidal-web", "", "", "", "", "", "", "", "", ""},
	}
	for _, c := range casos {
		t.Run(c.nombre, func(t *testing.T) {
			sp, dz, td, qz := DerivarIDsCrossDesdeFuente(c.source, c.trackID, c.sp, c.dz, c.td, c.qz)
			if sp != c.espSP || dz != c.espDZ || td != c.espTD || qz != c.espQZ {
				t.Fatalf("DerivarIDsCrossDesdeFuente(%q,%q,…) = (%q,%q,%q,%q); se esperaba (%q,%q,%q,%q)",
					c.source, c.trackID, sp, dz, td, qz, c.espSP, c.espDZ, c.espTD, c.espQZ)
			}
		})
	}
}
