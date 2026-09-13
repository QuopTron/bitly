package provider

import "testing"

func TestOriginalStrength_RejectsNonOriginal(t *testing.T) {
	cases := []struct {
		name        string
		queryTitle  string
		queryArtist string
		cand        TrackResult
		want        bool
	}{
		{
			name:        "exact original",
			queryTitle:  "Si Antes Te Hubiera Conocido",
			queryArtist: "KAROL G",
			cand:        TrackResult{Title: "Si Antes Te Hubiera Conocido", Artist: "KAROL G"},
			want:        true,
		},
		{
			name:        "remix rejected",
			queryTitle:  "Si Antes Te Hubiera Conocido",
			queryArtist: "KAROL G",
			cand:        TrackResult{Title: "Si Antes Te Hubiera Conocido (Remix)", Artist: "KAROL G"},
			want:        false,
		},
		{
			name:        "cover by another artist rejected",
			queryTitle:  "Si Antes Te Hubiera Conocido",
			queryArtist: "KAROL G",
			cand:        TrackResult{Title: "Si Antes Te Hubiera Conocido", Artist: "Some Cover Band"},
			want:        false,
		},
		{
			name:        "live rejected",
			queryTitle:  "La Bachata",
			queryArtist: "Manuel Turizo",
			cand:        TrackResult{Title: "La Bachata (Live)", Artist: "Manuel Turizo"},
			want:        false,
		},
		{
			name:        "acoustic rejected",
			queryTitle:  "Skyfall",
			queryArtist: "Adele",
			cand:        TrackResult{Title: "Skyfall (Acoustic)", Artist: "Adele"},
			want:        false,
		},
		{
			name:        "unrelated title rejected",
			queryTitle:  "Skyfall",
			queryArtist: "Adele",
			cand:        TrackResult{Title: "Rolling in the Deep", Artist: "Adele"},
			want:        false,
		},
		{
			name:        "wrong artist + same title rejected",
			queryTitle:  "Skyfall",
			queryArtist: "Adele",
			cand:        TrackResult{Title: "Skyfall", Artist: "Random Uploader"},
			want:        false,
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			_, ok := OriginalStrength(c.queryTitle, c.queryArtist, c.cand)
			if ok != c.want {
				t.Fatalf("OriginalStrength(%q,%q,%q/%q) = %v, want %v",
					c.queryTitle, c.queryArtist, c.cand.Title, c.cand.Artist, ok, c.want)
			}
		})
	}
}

// Las fuentes sin ISRC (YouTube/SoundCloud) suben la misma canción varias veces
// con el mismo título y artista. Sin desempate por duración el backend podía
// servir el audio equivocado (otra toma/corte). Estos casos lo bloquean.
func TestRankOriginalCandidatesDuracion_DesempataMismaCancion(t *testing.T) {
	// Mismo título y artista; distintas duraciones (versión de álbum vs. una
	// toma extendida subida al mismo canal).
	results := []TrackResult{
		{ID: "larga", Title: "La Bachata", Artist: "Manuel Turizo", Duration: 5 * 60 * 1000},
		{ID: "buena", Title: "La Bachata", Artist: "Manuel Turizo", Duration: 200 * 1000},
		{ID: "corta", Title: "La Bachata", Artist: "Manuel Turizo", Duration: 60 * 1000},
	}
	best := BestOriginalDuracion("La Bachata", "Manuel Turizo", 201*1000, results)
	if best == nil || best.ID != "buena" {
		t.Fatalf("BestOriginalDuracion eligió %+v, quería la de duración más cercana (buena)", best)
	}
}

func TestRankOriginalCandidatesDuracion_NoDescartaSinDuracion(t *testing.T) {
	// SoundCloud no siempre expone duración: el candidato sin duración no se
	// descarta (perdería contra uno con duración conocida, pero sigue válido si
	// es el único). Acá es el único original -> debe devolverse.
	results := []TrackResult{
		{ID: "sin-dur", Title: "Dai Dai", Artist: "minecraftdiablo", Duration: 0},
	}
	best := BestOriginalDuracion("Dai Dai", "Shakira", 190*1000, results)
	if best == nil || best.ID != "sin-dur" {
		t.Fatalf("BestOriginalDuracion descartó un candidato sin duración: %+v", best)
	}
}

func TestRankOriginalCandidatesDuracion_NuncaPromuevePeor(t *testing.T) {
	// El candidato con título EXACTO y duración lejana no debe ceder su lugar
	// ante uno de título más débil que casualmente dura lo mismo: la duración
	// es desempate, no criterio principal.
	results := []TrackResult{
		{ID: "exacto", Title: "La Bachata", Artist: "Manuel Turizo", Duration: 5 * 60 * 1000},
		{ID: "parecido", Title: "La Bachata (Cover)", Artist: "Manuel Turizo", Duration: 200 * 1000},
	}
	best := BestOriginalDuracion("La Bachata", "Manuel Turizo", 200*1000, results)
	if best == nil || best.ID != "exacto" {
		t.Fatalf("la duración promovió un candidato peor: %+v", best)
	}
}

func TestDistanciaDuracionMS(t *testing.T) {
	if distanciaDuracionMS(200000, 205000) != 5000 {
		t.Fatal("distancia con ambas conocidas")
	}
	if distanciaDuracionMS(200000, 0) != duracionDesconocida {
		t.Fatal("candidato sin duración debe pesar como desconocido")
	}
}

func TestBestOriginal_AcceptsFeat(t *testing.T) {
	results := []TrackResult{
		{ID: "1", Title: "DÁKITI", Artist: "Bad Bunny & Jhay Cortez"},
		{ID: "2", Title: "DÁKITI (Remix)", Artist: "Bad Bunny"},
		{ID: "3", Title: "DÁKITI", Artist: "Other"},
	}
	best := BestOriginal("DÁKITI", "Bad Bunny", results)
	if best == nil || best.ID != "1" {
		t.Fatalf("BestOriginal picked %+v, want ID=1", best)
	}
}

// El bug real que reporta el usuario: "cae en un remix la mayoría de las
// canciones". El último recurso por nombre aceptaba CUALQUIER artista con tal de
// que el título fuera fuerte, así que un homónimo de otro artista real (o un
// cover sin marcador) competía de igual a igual con el re-subido de la canción
// pedida. Estos casos fijan el orden: el candidato relacionable primero.
func TestRankOriginalCandidates_HomonimoSinEvidenciaVaUltimo(t *testing.T) {
	results := []TrackResult{
		{ID: "homonimo", Title: "La Bachata", Artist: "Grupo Frontera"},
		{ID: "resubido", Title: "La Bachata", Artist: "Latin Hits"},
	}
	ranked := RankOriginalCandidates("La Bachata", "Manuel Turizo", results)
	if len(ranked) != 2 {
		t.Fatalf("no se descarta a nadie: got %d candidatos, want 2", len(ranked))
	}
	if ranked[0].ID != "resubido" {
		t.Fatalf("el homónimo de otro artista quedó primero: %+v", ranked)
	}
}

// El desempate por duración NO puede cruzar el orden por evidencia de artista:
// si el homónimo dura exactamente lo mismo que la canción pedida, no debe saltar
// por delante de un canal de re-subida. (Regresión del bonus en puntajeEfectivo.)
func TestRankOriginalCandidatesDuracion_NoCruzaEvidenciaDeArtista(t *testing.T) {
	results := []TrackResult{
		{ID: "homonimo", Title: "La Bachata", Artist: "Grupo Frontera", Duration: 200 * 1000},
		{ID: "resubido", Title: "La Bachata", Artist: "Latin Hits", Duration: 400 * 1000},
	}
	ranked := RankOriginalCandidatesDuracion("La Bachata", "Manuel Turizo", 200*1000, results)
	if len(ranked) == 0 || ranked[0].ID != "resubido" {
		t.Fatalf("la duración promovió el homónimo: %+v", ranked)
	}
}

// Sin artista en la consulta no hay evidencia posible: el orden debe quedar
// como estaba (solo por título), sin regresión para las búsquedas por título.
func TestRankOriginalCandidates_SinArtistaMantieneOrden(t *testing.T) {
	results := []TrackResult{
		{ID: "exacto", Title: "La Bachata", Artist: "Alguien"},
		{ID: "parcial", Title: "Bachata", Artist: "Otro"},
	}
	ranked := RankOriginalCandidates("La Bachata", "", results)
	if len(ranked) != 2 || ranked[0].ID != "exacto" {
		t.Fatalf("búsqueda por título cambió de orden: %+v", ranked)
	}
}

func TestEsCanalDeResubida(t *testing.T) {
	canales := []string{"Latin Hits", "Manuel Turizo - Topic", "LyricsVideos", "VEVO", "Top Music"}
	for _, c := range canales {
		if !EsCanalDeResubida(c) {
			t.Errorf("EsCanalDeResubida(%q) = false, want true", c)
		}
	}
	reales := []string{"Manuel Turizo", "", "Karol G", "Bad Bunny"}
	for _, a := range reales {
		if EsCanalDeResubida(a) {
			t.Errorf("EsCanalDeResubida(%q) = true, want false", a)
		}
	}
}

// The log on the device showed real tracks being rejected even though the
// candidate was the original song. These cases lock the fixes:
//  1. Official titles that contain "remix" ("MORNING DEW (DONK) REMIX") were
//     rejected because IsNonOriginalTitle flagged any "remix".
//  2. SoundCloud re-uploads carry the real artist in the TITLE and the uploader
//     in Artist ("Shakira - DAI DAI" / "minecraftdiablo") -> a=0, rejected.
//  3. Apple candidates reorder bonus/feat tokens ("suave. [bonus track]
//     (feat. Tokischa)" vs "suave. (feat. Tokischa) [bonus track]") -> t=1.
func TestOriginalStrength_AcceptsRealDeviceCases(t *testing.T) {
	cases := []struct {
		name        string
		queryTitle  string
		queryArtist string
		cand        TrackResult
		want        bool
	}{
		{
			name:        "official remix title accepted when query also has remix",
			queryTitle:  "MORNING DEW (DONK) REMIX FEAT JAŸ-Z",
			queryArtist: "Beyoncé, JAŸ-Z",
			cand:        TrackResult{Title: "MORNING DEW (DONK) REMIX [feat. JAŸ-Z]", Artist: "Beyoncé"},
			want:        true,
		},
		{
			name:        "soundcloud re-upload with artist in title",
			queryTitle:  "Dai Dai",
			queryArtist: "Shakira",
			cand:        TrackResult{Title: "Shakira - DAI DAI", Artist: "minecraftdiablo"},
			want:        true,
		},
		{
			name:        "reordered bonus track tokens",
			queryTitle:  "suave. (feat. Tokischa) [bonus track]",
			queryArtist: "Brent Faiyaz, Tokischa",
			cand:        TrackResult{Title: "suave. [bonus track] (feat. Tokischa)", Artist: "Brent Faiyaz & Tokischa"},
			want:        true,
		},
		{
			name:        "accent variant NFD title",
			queryTitle:  "Puñaladas",
			queryArtist: "Lauta",
			cand:        TrackResult{Title: "Pun\u0303aladas", Artist: "Lauta, Amigo de Artistas, Tote"},
			want:        true,
		},
		{
			name:        "still rejects non-original remix when query has none",
			queryTitle:  "La Bachata",
			queryArtist: "Manuel Turizo",
			cand:        TrackResult{Title: "Manuel Turizo - La Bachata (5HOURS Remix)", Artist: "Manuel Turizo"},
			want:        false,
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			_, ok := OriginalStrength(c.queryTitle, c.queryArtist, c.cand)
			if ok != c.want {
				t.Fatalf("OriginalStrength(%q,%q,%q/%q) = %v, want %v",
					c.queryTitle, c.queryArtist, c.cand.Title, c.cand.Artist, ok, c.want)
			}
		})
	}
}
