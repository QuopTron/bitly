package provider

import "testing"

// Cuando un proveedor puede dar fe de un ISRC y cuándo no. Los catálogos lo
// reciben del sello; el rescate por ISRC lo usa como índice. Los re-subidos
// (YouTube / YouTube Music / SoundCloud) lo INFIEREN por nombre, así que no.
func TestEsProveedorAutoritativoISRC(t *testing.T) {
	autoritativos := []string{"deezer", "deezer-web", "qobuz", "qobuz-web", "tidal", "tidal-web",
		"amazon", "apple-music", "flac-rescue", "musicbrainz"}
	for _, n := range autoritativos {
		if !EsProveedorAutoritativoISRC(n) {
			t.Errorf("EsProveedorAutoritativoISRC(%q) = false, quería true", n)
		}
	}
	// Los que identifican canciones por NOMBRE nunca dan fe del ISRC.
	for _, n := range []string{"youtube", "ytmusic-spotiflac", "soundcloud", ""} {
		if EsProveedorAutoritativoISRC(n) {
			t.Errorf("EsProveedorAutoritativoISRC(%q) = true, quería false", n)
		}
	}
}

// flac-rescue no tiene catálogo: su título ES el ISRC y va sin artista. Debe
// contar como coincidencia exacta (antes se rechazaba y el rescate FLAC por ISRC
// nunca podía servir la canción).
func TestEsCandidatoPorISRC(t *testing.T) {
	casos := []struct {
		nombre string
		isrc   string
		track  *TrackResult
		want   bool
	}{
		{
			nombre: "flac-rescue: título == ISRC",
			isrc:   "USRC17607839",
			track:  &TrackResult{ID: "USRC17607839", Title: "USRC17607839", ISRC: "USRC17607839"},
			want:   true,
		},
		{
			nombre: "flac-rescue: sin título",
			isrc:   "USRC17607839",
			track:  &TrackResult{ID: "USRC17607839", ISRC: "USRC17607839"},
			want:   true,
		},
		{
			nombre: "ISRC distinto",
			isrc:   "USRC17607839",
			track:  &TrackResult{Title: "OTRO0000001", ISRC: "OTRO0000001"},
			want:   false,
		},
		{
			nombre: "con título real (no es un índice por ISRC)",
			isrc:   "USRC17607839",
			track:  &TrackResult{Title: "Mi Cancion", ISRC: "USRC17607839"},
			want:   false,
		},
		{
			nombre: "sin ISRC declarado",
			isrc:   "USRC17607839",
			track:  &TrackResult{Title: "USRC17607839"},
			want:   false,
		},
		{
			nombre: "track nil",
			isrc:   "USRC17607839",
			track:  nil,
			want:   false,
		},
	}
	for _, c := range casos {
		if got := EsCandidatoPorISRC(c.isrc, c.track); got != c.want {
			t.Errorf("%s: EsCandidatoPorISRC = %v, quería %v", c.nombre, got, c.want)
		}
	}
}

// PreferirISRC adelanta la candidata que declara el ISRC pedido sin descartar el
// resto (SoundCloud/YouTube no siempre lo exponen) y sin romper el orden interno.
func TestPreferirISRC(t *testing.T) {
	cands := []TrackResult{
		{ID: "a", Title: "Cancion", ISRC: ""},
		{ID: "b", Title: "Cancion", ISRC: "OTRO0000001"},
		{ID: "c", Title: "Cancion", ISRC: "USRC17607839"},
	}
	got := PreferirISRC("USRC17607839", cands)
	if got[0].ID != "c" {
		t.Fatalf("PreferirISRC dejó %q primero, quería la candidata con el ISRC pedido", got[0].ID)
	}
	// No se descarta ninguna y se conserva el orden original entre las demás.
	if len(got) != 3 || got[1].ID != "a" || got[2].ID != "b" {
		t.Fatalf("PreferirISRC perdió o reordenó candidatas: %+v", got)
	}

	// Sin coincidencias, el orden no cambia.
	sinMatch := PreferirISRC("XXXX0000000", cands)
	if len(sinMatch) != 3 || sinMatch[0].ID != "a" {
		t.Fatalf("PreferirISRC reordenó sin coincidencias: %+v", sinMatch)
	}
}
