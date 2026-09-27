package gobackend

import (
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// EL CONTRATO QUE ESTE TEST FIJA
// El canal sin pérdida ya no depende de que el pedido traiga ISRC. Un tema de
// YouTube/SoundCloud entra SIN ISRC (sus catálogos no lo publican) y antes se
// quedaba con el stream lossy por nombre porque el canal ni se abría. Ahora se
// abre igual: deriva el ISRC en paralelo y, apenas lo tiene, pide el FLAC. La
// derivación es la misma del rescate (solo un original verificado), así que un
// ISRC dudoso sigue sin abrir el canal. Y nada de esto se paga cuando la
// calidad no es sin pérdida o no hay título/artista con qué buscar.

// provStub implementa provider.Provider para los dos lados del canal: el
// catálogo que publica el ISRC (SearchTracks) y la fuente sin pérdida que lo
// resuelve por ISRC (GetTrackByISRC + GetStreamURL).
type provStub struct {
	nombre    string
	candidato provider.TrackResult // lo que devuelve SearchTracks
	porISRC   *provider.TrackResult
	flac      string
}

func (p *provStub) Name() string { return p.nombre }

func (p *provStub) SearchTracks(query string, limit int) ([]provider.TrackResult, error) {
	if p.candidato.Title == "" {
		return nil, nil
	}
	return []provider.TrackResult{p.candidato}, nil
}

func (p *provStub) SearchAlbums(query string, limit int) ([]provider.AlbumResult, error) {
	return nil, nil
}
func (p *provStub) SearchArtists(query string, limit int) ([]provider.ArtistResult, error) {
	return nil, nil
}
func (p *provStub) SearchPlaylists(query string, limit int) ([]provider.PlaylistResult, error) {
	return nil, nil
}
func (p *provStub) GetTrack(id string) (*provider.TrackResult, error) { return nil, nil }
func (p *provStub) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	return p.porISRC, nil
}
func (p *provStub) GetAlbum(id string) (*provider.AlbumResult, error)   { return nil, nil }
func (p *provStub) GetArtist(id string) (*provider.ArtistResult, error) { return nil, nil }
func (p *provStub) GetStreamURL(id, quality string) (string, error)     { return p.flac, nil }

// conRegistro publica [provs] en el registry global del paquete y lo restaura.
func conRegistro(t *testing.T, provs ...provider.Provider) {
	t.Helper()
	previo := reg
	reg = provider.NewRegistry()
	for _, p := range provs {
		reg.Register(p)
	}
	t.Cleanup(func() { reg = previo })
}

const urlFLACPrueba = "https://arcod.test/tema.flac"

// catalogoConISRC arma el catálogo que publica el ISRC de un original.
func catalogoConISRC(titulo, artista string, durMS int, isrc string) *provStub {
	return &provStub{
		nombre: "deezer",
		candidato: provider.TrackResult{
			ID: "cat-1", Title: titulo, Artist: artista, Duration: durMS, ISRC: isrc,
		},
	}
}

// fuenteFLAC arma la fuente sin pérdida que resuelve el ISRC a un FLAC vivo.
func fuenteFLAC() *provStub {
	return &provStub{
		nombre:  "flac-rescue",
		porISRC: &provider.TrackResult{ID: "arcod-1", Title: "tema", Artist: "artista", ISRC: "US0000000001"},
		flac:    urlFLACPrueba,
	}
}

func TestCanalSinPerdidaDerivaISRCYEntregaElFLAC(t *testing.T) {
	titulo, artista, dur := "Tema Sin Isrc", "Artista Nuevo", 214000
	conRegistro(t, catalogoConISRC(titulo, artista, dur, "US0000000001"), fuenteFLAC())
	cooldown.MarkOk("deezer")
	cooldown.MarkOk("flac-rescue")

	params := &streamPackageParams{Quality: "flac", TrackName: titulo, ArtistName: artista, DurationMS: dur}
	c := abrirCanalSinPerdida(params)
	if c == nil {
		t.Fatal("abrirCanalSinPerdida = nil; con título/artista y sin ISRC debe abrir el canal")
	}
	if !c.derivando {
		t.Error("derivando = false; el pedido no traía ISRC y el canal debe derivarlo")
	}

	url, name := paqueteConElMejorAudio(c, params, "https://youtube.test/lossy", "youtube")
	if url != urlFLACPrueba || name != "flac-rescue" {
		t.Errorf("paqueteConElMejorAudio = (%q, %q); se esperaba el FLAC derivado", url, name)
	}
}

func TestCanalSinPerdidaConISRCDirectoNoDeriva(t *testing.T) {
	dur := 199000
	conRegistro(t, fuenteFLAC())
	cooldown.MarkOk("flac-rescue")

	params := &streamPackageParams{Quality: "flac", TrackName: "Tema", ArtistName: "Artista", DurationMS: dur, ISRC: "US0000000001"}
	c := abrirCanalSinPerdida(params)
	if c == nil {
		t.Fatal("abrirCanalSinPerdida = nil; con ISRC debe abrir el canal")
	}
	if c.derivando {
		t.Error("derivando = true; con ISRC ya no hay nada que derivar")
	}
	if url, name := paqueteConElMejorAudio(c, params, "https://youtube.test/lossy", "youtube"); url != urlFLACPrueba || name != "flac-rescue" {
		t.Errorf("paqueteConElMejorAudio = (%q, %q); se esperaba el FLAC por ISRC directo", url, name)
	}
}

func TestCanalSinPerdidaSinISRSinOriginalNoBloquea(t *testing.T) {
	// Catálogo que NO tiene la canción: la derivación devuelve "" y el canal
	// debe acusar el final con un vacío para que el llamador se quede con su
	// audio con pérdida sin esperar la ventana completa.
	titulo, artista, dur := "Tema Inexistente", "Nadie", 180000
	conRegistro(t, &provStub{nombre: "deezer"}, fuenteFLAC())
	cooldown.MarkOk("deezer")
	cooldown.MarkOk("flac-rescue")

	params := &streamPackageParams{Quality: "flac", TrackName: titulo, ArtistName: artista, DurationMS: dur}
	c := abrirCanalSinPerdida(params)
	if c == nil {
		t.Fatal("abrirCanalSinPerdida = nil; hay título/artista con qué intentar derivar")
	}
	inicio := time.Now()
	url, name := paqueteConElMejorAudio(c, params, "https://youtube.test/lossy", "youtube")
	if url != "https://youtube.test/lossy" || name != "youtube" {
		t.Errorf("paqueteConElMejorAudio = (%q, %q); sin ISRC debe seguir el audio con pérdida", url, name)
	}
	if transcurrido := time.Since(inicio); transcurrido >= time.Second {
		t.Errorf("esperó %s por una derivación imposible; el canal debe acusar el final enseguida", transcurrido)
	}
}

func TestCanalSinPerdidaNoSeAbreSinLosslessNiSinIdentidad(t *testing.T) {
	casos := []struct {
		nombre string
		params streamPackageParams
	}{
		{"calidad con pérdida", streamPackageParams{Quality: "320", TrackName: "Tema", ArtistName: "Artista"}},
		{"sin título", streamPackageParams{Quality: "flac", ArtistName: "Artista"}},
		{"sin artista", streamPackageParams{Quality: "flac", TrackName: "Tema"}},
	}
	for _, caso := range casos {
		if c := abrirCanalSinPerdida(&caso.params); c != nil {
			t.Errorf("%s: abrirCanalSinPerdida abrió el canal; no debe pagar nada", caso.nombre)
		}
	}
}
