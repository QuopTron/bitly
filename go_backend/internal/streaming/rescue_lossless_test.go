// ─────────────────────────────────────────────────────────────
// rescue_lossless_test.go — Pincha el canal SIN PÉRDIDA de la reproducción:
//
//  1. Solo se abre cuando la calidad pedida es sin pérdida y hay ISRC (si no,
//     no paga ni una petición).
//  2. Consulta SOLO fuentes que pueden dar FLAC en vivo (flac-rescue / Internet
//     Archive): YouTube y compañía no entran acá — el camino rápido ya las
//     cubre y sondearlas sería duplicar carga.
//  3. Pide UNA sola calidad, la sin pérdida: la cascada de calidades devolvería
//     un MP3 y este canal existe para no conformarse con el transcodificado.
//
// Run: cd go_backend && go test ./internal/streaming/ -run SinPerdida -v
// ─────────────────────────────────────────────────────────────

package streaming

import (
	"errors"
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// stubLossless es un proveedor con ISRC resoluble y memoria de las calidades
// que le pidieron (para probar que NO se prueba una cascada con pérdida).
type stubLossless struct {
	name      string
	resuelve  func() (string, error)
	calidades []string
}

func (s *stubLossless) Name() string { return s.name }
func (s *stubLossless) SearchTracks(q string, l int) ([]provider.TrackResult, error) {
	return nil, nil
}
func (s *stubLossless) SearchAlbums(q string, l int) ([]provider.AlbumResult, error) {
	return nil, nil
}
func (s *stubLossless) SearchArtists(q string, l int) ([]provider.ArtistResult, error) {
	return nil, nil
}
func (s *stubLossless) SearchPlaylists(q string, l int) ([]provider.PlaylistResult, error) {
	return nil, nil
}
func (s *stubLossless) GetTrack(id string) (*provider.TrackResult, error) { return nil, nil }
func (s *stubLossless) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	return &provider.TrackResult{ID: isrc, Title: isrc, ISRC: isrc, Provider: s.name}, nil
}
func (s *stubLossless) GetAlbum(id string) (*provider.AlbumResult, error)   { return nil, nil }
func (s *stubLossless) GetArtist(id string) (*provider.ArtistResult, error) { return nil, nil }
func (s *stubLossless) GetStreamURL(id, quality string) (string, error) {
	s.calidades = append(s.calidades, quality)
	return s.resuelve()
}

// armaRegistroSinPerdida registra la cadena real de audio: las dos fuentes sin
// pérdida en vivo más un re-subido (que NO debe ser consultado por este canal).
func armaRegistroSinPerdida(flac func() (string, error), archivo func() (string, error)) (*provider.Registry, *stubLossless, *stubLossless, *stubLossless) {
	for _, n := range []string{"ytmusic-spotiflac", "youtube", "flac-rescue", "internetarchive"} {
		cooldown.MarkOk(n)
	}
	flacStub := &stubLossless{name: "flac-rescue", resuelve: flac}
	archStub := &stubLossless{name: "internetarchive", resuelve: archivo}
	ytStub := &stubLossless{name: "ytmusic-spotiflac", resuelve: func() (string, error) {
		return "http://youtube/stream", nil
	}}
	reg := provider.NewRegistry()
	reg.Register(ytStub)
	reg.Register(&stubLossless{name: "youtube", resuelve: func() (string, error) { return "", nil }})
	reg.Register(flacStub)
	reg.Register(archStub)
	return reg, flacStub, archStub, ytStub
}

// TestSinPerdidaSoloCuandoCorresponde: sin ISRC o con calidad con pérdida el
// canal no existe (devuelve nil / vacío y no toca ningún proveedor).
func TestSinPerdidaSoloCuandoCorresponde(t *testing.T) {
	reg, _, _, _ := armaRegistroSinPerdida(
		func() (string, error) { return "http://arcod/flac", nil },
		func() (string, error) { return "", errors.New("no tengo") },
	)
	if u, p := StreamLosslessPorISRC(reg, "", "flac"); u != "" || p != "" {
		t.Fatalf("sin ISRC no debe resolver nada (dio %q / %q)", u, p)
	}
	if u, p := StreamLosslessPorISRC(reg, "QMFMF2447055", "high"); u != "" || p != "" {
		t.Fatalf("con calidad con pérdida no debe resolver nada (dio %q / %q)", u, p)
	}
	if !CalidadPideLossless("flac") || !CalidadPideLossless("HI_RES_LOSSLESS") {
		t.Fatal("CalidadPideLossless no reconoce los pedidos sin pérdida")
	}
	if CalidadPideLossless("high") || CalidadPideLossless("") {
		t.Fatal("CalidadPideLossless marca como sin pérdida algo que no lo es")
	}
}

// TestSinPerdidaResuelveElFlac: con el canal vivo entrega el enlace y dice de
// quién salió; y solo le pidió UNA calidad (la sin pérdida).
func TestSinPerdidaResuelveElFlac(t *testing.T) {
	reg, flac, _, yt := armaRegistroSinPerdida(
		func() (string, error) { return "http://arcod/flac", nil },
		func() (string, error) { return "", errors.New("no tengo") },
	)
	url, prov := StreamLosslessPorISRC(reg, "QMFMF2447055", "flac")
	if url != "http://arcod/flac" || prov != "flac-rescue" {
		t.Fatalf("se esperaba el FLAC de flac-rescue, llegó %q / %q", url, prov)
	}
	if len(flac.calidades) != 1 || flac.calidades[0] != "flac" {
		t.Fatalf("flac-rescue recibió %v: este canal pide solo la calidad sin pérdida", flac.calidades)
	}
	if len(yt.calidades) != 0 {
		t.Fatalf("el re-subido fue consultado (%v): el canal sin pérdida no debe sondearlo", yt.calidades)
	}
}

// TestCarreraCerradaNoPierdeElStreamYaEncolado fija el invariante del colector
// de la carrera: un stream que YA está en el canal se entrega, aunque el canal
// ya esté cerrado.
//
// El bug que evita: los workers terminaban avisando por un canal `done` APARTE,
// y `select` elige al azar entre casos listos. Cuando el resultado quedaba
// encolado y `done` se cerraba sin que el colector hubiera sido programado,
// elegir `done` devolvía vacío teniendo la URL en la mano: la reproducción se
// quedaba sin audio (y el canal sin pérdida perdía su FLAC) de forma
// intermitente, sobre todo bajo carga. Con el canal de resultados cerrándose a
// sí mismo, Go entrega el buffer ENTERO antes de reportar el cierre, así que no
// hay azar posible: el stream encolado gana siempre.
func TestCarreraCerradaNoPierdeElStreamYaEncolado(t *testing.T) {
	ch := make(chan rescueOut, 2)
	ch <- rescueOut{name: "flac-rescue", url: "http://arcod/flac"}
	close(ch) // el worker ya terminó: cierre y resultado listos a la vez

	deadline := time.Now().Add(time.Second)
	url, prov, verified := recogerResultados(ch, make(chan string, 1), &deadline, 0, politicaCarrera{})
	if url != "http://arcod/flac" || prov != "flac-rescue" || verified {
		t.Fatalf("se perdió el stream ya encolado: url=%q prov=%q verified=%v", url, prov, verified)
	}
}

// TestSinPerdidaNoCuelgaCuandoNoHayTema: si las fuentes sin pérdida no tienen
// el tema, el canal vuelve VACÍO y rápido — el llamador conserva su audio con
// pérdida en vez de quedarse esperando.
func TestSinPerdidaNoCuelgaCuandoNoHayTema(t *testing.T) {
	reg, _, _, _ := armaRegistroSinPerdida(
		func() (string, error) { return "", errors.New("sin FLAC") },
		func() (string, error) { return "", errors.New("sin FLAC") },
	)
	inicio := time.Now()
	url, prov := StreamLosslessPorISRC(reg, "QMFMF2447055", "flac")
	if url != "" || prov != "" {
		t.Fatalf("no había FLAC y devolvió %q / %q", url, prov)
	}
	if tardanza := time.Since(inicio); tardanza > PresupuestoSinPerdida {
		t.Fatalf("tardó %s: se pasó del presupuesto del canal", tardanza)
	}
	if PresupuestoSinPerdida >= 3*time.Second {
		t.Fatal("el presupuesto del canal no puede acercarse al de la fase exacta del rescate")
	}
}
