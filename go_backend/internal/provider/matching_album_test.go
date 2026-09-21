package provider

import "testing"

// El caso reportado: se descargaba/reproducía la toma de OTRO disco. Título y
// artista coinciden (es la misma canción), así que sin el álbum el ranking no
// tenía con qué distinguir la versión del álbum original de la de un
// recopilatorio o de un "remix album".
func TestRankOriginalCandidatesAlbum_PrefiereElDiscoPedido(t *testing.T) {
	results := []TrackResult{
		{ID: "recopilatorio", Title: "NUEVAYoL", Artist: "Bad Bunny", Album: "Grandes Exitos 2025"},
		{ID: "remix-album", Title: "NUEVAYoL", Artist: "Bad Bunny", Album: "NUEVAYoL (Remixes)"},
		{ID: "original", Title: "NUEVAYoL", Artist: "Bad Bunny", Album: "Un Verano Sin Ti"},
	}
	best := BestOriginalAlbumDuracion("NUEVAYoL", "Bad Bunny", "Un Verano Sin Ti", 0, results)
	if best == nil || best.ID != "original" {
		t.Fatalf("eligió %+v, quería la toma del álbum pedido", best)
	}
	// Y NINGUNO se descarta: un álbum distinto no es un rechazo (los catálogos
	// renombran las ediciones y los re-subidos no traen álbum).
	ranked := RankOriginalCandidatesAlbum("NUEVAYoL", "Bad Bunny", "Un Verano Sin Ti", 0, results)
	if len(ranked) != len(results) {
		t.Fatalf("el álbum descartó candidatos: %d de %d", len(ranked), len(results))
	}
}

// Los re-subidos (YouTube/SoundCloud) no exponen álbum: el candidato sin álbum
// pierde contra el del disco pedido, pero sigue siendo válido cuando es el único.
func TestRankOriginalCandidatesAlbum_SinAlbumNoSeDescarta(t *testing.T) {
	results := []TrackResult{
		{ID: "resubido", Title: "La Bachata", Artist: "Manuel Turizo", Album: ""},
	}
	best := BestOriginalAlbumDuracion("La Bachata", "Manuel Turizo", "La Bachata", 0, results)
	if best == nil || best.ID != "resubido" {
		t.Fatalf("descartó el candidato sin álbum: %+v", best)
	}
}

// La edición de lujo del MISMO disco sigue puntuando alto (contiene el nombre
// pedido) y por eso va antes que otra edición ajena.
func TestAlbumScore(t *testing.T) {
	cases := []struct {
		name  string
		query string
		cand  string
		want  float64
	}{
		{"exacto", "Un Verano Sin Ti", "Un Verano Sin Ti", 3},
		{"deluxe es del mismo disco", "Un Verano Sin Ti", "Un Verano Sin Ti (Deluxe)", 2},
		{"otro disco", "Un Verano Sin Ti", "Grandes Exitos", 0},
		{"sin álbum", "Un Verano Sin Ti", "", 0},
		{"sin álbum pedido", "", "Un Verano Sin Ti", 0},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := AlbumScore(c.query, c.cand); got != c.want {
				t.Fatalf("AlbumScore(%q,%q) = %v, want %v", c.query, c.cand, got, c.want)
			}
		})
	}
}

// Sin álbum en el pedido el orden debe ser EXACTAMENTE el del desempate por
// duración de siempre: el álbum es un criterio nuevo, no un cambio de conducta
// para los pedidos que no lo traen (búsqueda, feed, detalle sin álbum).
func TestRankOriginalCandidatesAlbum_SinAlbumNoCambiaElOrden(t *testing.T) {
	results := []TrackResult{
		{ID: "larga", Title: "La Bachata", Artist: "Manuel Turizo", Duration: 5 * 60 * 1000},
		{ID: "buena", Title: "La Bachata", Artist: "Manuel Turizo", Duration: 200 * 1000},
		{ID: "corta", Title: "La Bachata", Artist: "Manuel Turizo", Duration: 60 * 1000},
	}
	nuevo := RankOriginalCandidatesAlbum("La Bachata", "Manuel Turizo", "", 201*1000, results)
	viejo := RankOriginalCandidatesDuracion("La Bachata", "Manuel Turizo", 201*1000, results)
	if len(nuevo) != len(viejo) {
		t.Fatalf("distinta cantidad: %d vs %d", len(nuevo), len(viejo))
	}
	for i := range nuevo {
		if nuevo[i].ID != viejo[i].ID {
			t.Fatalf("posición %d: %q vs %q (el álbum vacío no debe reordenar)", i, nuevo[i].ID, viejo[i].ID)
		}
	}
}

// El álbum es DESEMPATE, no criterio principal: un candidato con título débil no
// puede adelantar a uno con título exacto solo porque el álbum coincida.
func TestRankOriginalCandidatesAlbum_NuncaPromuevePeor(t *testing.T) {
	results := []TrackResult{
		{ID: "exacto-otro-disco", Title: "La Bachata", Artist: "Manuel Turizo", Album: "Otro Disco"},
		{ID: "debil-mismo-disco", Title: "La Bachata Karaoke Version", Artist: "Manuel Turizo", Album: "La Bachata"},
	}
	best := BestOriginalAlbumDuracion("La Bachata", "Manuel Turizo", "La Bachata", 0, results)
	if best == nil || best.ID != "exacto-otro-disco" {
		t.Fatalf("el álbum promovió un candidato peor: %+v", best)
	}
}
