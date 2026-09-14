package gobackend

import "testing"

// EL BUG QUE ESTE TEST FIJA
// La búsqueda por extensión pasaba los resultados por una sola pasada ESTRICTA
// (título fuerte + artista confirmado en el campo Artist). Eso devolvía vacío en
// dos casos normales: la consulta escrita como un bloque sin separador
// ("Daft Punk One More Time" → el artista consultado queda vacío, y FieldScore de
// "" es 0 siempre) y el caso del uploader en Artist con el artista real dentro
// del título. Medido en el emulador: Amazon devolvía 12 resultados y Spotify 25,
// y el stream terminaba con CERO — la búsqueda se veía muerta.
//
// La segunda pasada es la misma política que RankOriginalCandidates usa en el
// camino nativo: nunca promueve un cover/remix, solo deja de tirar el original.

func track(name, artist string) FeedItemGo {
	return FeedItemGo{ID: name + "|" + artist, Name: name, Artists: artist, Type: "track"}
}

func TestFiltrarOriginalesConsultaSinSeparadorNoQuedaVacia(t *testing.T) {
	// Lo que devuelve la extensión para "Daft Punk One More Time".
	items := []FeedItemGo{
		track("One More Time", "Daft Punk"),
		track("One More Time (Remastered)", "Daft Punk"),
	}

	// splitSearchQuery deja el título completo y artista vacío.
	got := filtrarOriginales(items, "Daft Punk One More Time", "")
	if len(got) == 0 {
		t.Fatal("la búsqueda quedó vacía: la pasada best-effort no está funcionando")
	}
	if got[0].Name != "One More Time" {
		t.Errorf("primer resultado = %q, quería \"One More Time\"", got[0].Name)
	}
}

func TestFiltrarOriginalesSigueEchandoLoQueNoEsLaCancion(t *testing.T) {
	items := []FeedItemGo{
		track("Bohemian Rhapsody", "Queen"),
		track("Otra Cancion Distinta", "Otro Artista"),
	}

	// Título flojo respecto de la consulta: se descarta. Un resultado de más con
	// la canción equivocada es peor que no mostrar nada.
	if got := filtrarOriginales(items, "Daft Punk One More Time", ""); len(got) != 0 {
		t.Errorf("filtrarOriginales dejó pasar %d resultados que no son la canción", len(got))
	}
}

func TestFiltrarOriginalesNoPromueveRemixNiCover(t *testing.T) {
	items := []FeedItemGo{
		// Mismo título, pero es una variante: la consulta no la pide.
		track("One More Time (Remix)", "Daft Punk"),
	}

	// La variante tiene título fuerte (contiene la consulta) pero es variante:
	// fuera, igual que en el camino nativo.
	if got := filtrarOriginales(items, "One More Time", "Daft Punk"); len(got) != 0 {
		t.Errorf("filtrarOriginales promovió una variante: %+v", got)
	}
}

func TestFiltrarOriginalesPrefiereLosEstrictos(t *testing.T) {
	items := []FeedItemGo{
		track("One More Time", "Otro Artista"), // best-effort
		track("One More Time", "Daft Punk"),    // estricto (artista confirmado)
	}

	got := filtrarOriginales(items, "One More Time", "Daft Punk")
	if len(got) != 1 {
		t.Fatalf("quería solo el original estricto, llegaron %d", len(got))
	}
	if got[0].Artists != "Daft Punk" {
		t.Errorf("se quedó el candidato equivocado: %q", got[0].Artists)
	}
}

func TestFiltrarOriginalesConservaLoQueNoEsTrack(t *testing.T) {
	items := []FeedItemGo{
		{ID: "alb-1", Name: "Discovery", Artists: "Daft Punk", Type: "album"},
	}
	got := filtrarOriginales(items, "Daft Punk One More Time", "")
	if len(got) != 1 || got[0].Type != "album" {
		t.Errorf("las colecciones no se filtran como tracks: %+v", got)
	}
}
