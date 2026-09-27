// ─────────────────────────────────────────────────────────────
// rescue_identidad_test.go — Pincha la resolución del stream por IDENTIDAD
// EXACTA (rescue_identidad.go), que es la vía que usa la fase 1 del rescate.
//
// Lo que fija:
//  1. Una fuente que resuelve por ISRC entrega su stream (la fase exacta ya no
//     depende solo de flac-rescue).
//  2. Un candidato que NO es la grabación pedida se rechaza antes de streamear.
//  3. Sin ningún identificador no se sondea la fuente (ni se gasta un turno).
//  4. La identidad se completa desde el track cuando el llamador no trae
//     título/artista.
//  5. rescueStream NO repite la identidad que ya probó la fase de identificadores
//     — salvo que un ISRC nuevo llegue derivado en vuelo.
//
// Run: cd go_backend && go test ./internal/streaming/ -run Identidad -v
// ─────────────────────────────────────────────────────────────

package streaming

import (
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// identStub es un proveedor con ISRC resoluble y contador de intentos, para
// probar la resolución por identidad sin tocar la red.
type identStub struct {
	name      string
	track     *provider.TrackResult
	stream    string
	consultas int
}

func (s *identStub) Name() string { return s.name }
func (s *identStub) SearchTracks(q string, l int) ([]provider.TrackResult, error) {
	return nil, nil
}
func (s *identStub) SearchAlbums(q string, l int) ([]provider.AlbumResult, error) {
	return nil, nil
}
func (s *identStub) SearchArtists(q string, l int) ([]provider.ArtistResult, error) {
	return nil, nil
}
func (s *identStub) SearchPlaylists(q string, l int) ([]provider.PlaylistResult, error) {
	return nil, nil
}
func (s *identStub) GetTrack(id string) (*provider.TrackResult, error) { return s.track, nil }
func (s *identStub) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	s.consultas++
	return s.track, nil
}
func (s *identStub) GetAlbum(id string) (*provider.AlbumResult, error)   { return nil, nil }
func (s *identStub) GetArtist(id string) (*provider.ArtistResult, error) { return nil, nil }
func (s *identStub) GetStreamURL(id, quality string) (string, error)     { return s.stream, nil }

// TestResolverStreamPorIdentidadEntregaElStream: una fuente que resuelve por
// ISRC entrega su stream y sin buscar por nombre.
func TestResolverStreamPorIdentidadEntregaElStream(t *testing.T) {
	const isrc = "USRC17607839"
	stub := &identStub{
		name:   "flac-rescue",
		track:  &provider.TrackResult{ID: isrc, Title: isrc, ISRC: isrc, Provider: "flac-rescue"},
		stream: "http://arcod/flac",
	}
	url, verified := resolverStreamPorIdentidad(stub, "flac", datosIdentidad{isrc: isrc})
	if url != "http://arcod/flac" || verified {
		t.Fatalf("se esperaba el stream por ISRC, llegó %q verified=%v", url, verified)
	}
	if stub.consultas == 0 {
		t.Fatal("no se consultó el ISRC en la fuente")
	}
}

// TestResolverStreamPorIdentidadRechazaOtraCancion: aunque la fuente devuelva un
// id para el ISRC pedido, si el registro trae OTRO ISRC no es la grabación: no
// se streamea (el guard de identidad vale incluso cuando el id vino "resuelto").
func TestResolverStreamPorIdentidadRechazaOtraCancion(t *testing.T) {
	const isrc = "USRC17607839"
	stub := &identStub{
		name:   "soundcloud",
		track:  &provider.TrackResult{ID: "123", Title: "Otra Cancion", Artist: "Otro", ISRC: "OTRO0000001", Duration: 200000},
		stream: "http://otra/cancion",
	}
	url, _ := resolverStreamPorIdentidad(stub, "high", datosIdentidad{
		isrc: isrc, title: "Mi Cancion", artist: "Artista Real", durationMS: 200000,
	})
	if url != "" {
		t.Fatalf("streameó una canción distinta: %q", url)
	}
}

// TestResolverStreamPorIdentidadSinIdentificadoresNoSondea: sin ISRC ni ids no
// hay nada que resolver — no se gasta un turno del pool.
func TestResolverStreamPorIdentidadSinIdentificadoresNoSondea(t *testing.T) {
	stub := &identStub{name: "flac-rescue", stream: "http://arcod/flac"}
	url, _ := resolverStreamPorIdentidad(stub, "high", datosIdentidad{title: "Tema", artist: "Artista"})
	if url != "" {
		t.Fatalf("resolvió sin identificadores: %q", url)
	}
	if stub.consultas != 0 {
		t.Fatalf("sondeó la fuente sin identificadores (%d consultas)", stub.consultas)
	}
}

// TestIdentidadDeTrackCompletaDesdeElTrack: el llamador puede no traer
// título/artista; se completan desde el track del pedido, junto con los ids.
func TestIdentidadDeTrackCompletaDesdeElTrack(t *testing.T) {
	track := &provider.TrackResult{
		ISRC: "USRC17607839", Title: "Tema Del Track", Artist: "Artista Del Track",
		SpotifyID: "sp", DeezerID: "dz", TidalID: "td", QobuzID: "qz", Duration: 210000,
	}
	d := identidadDeTrack(track, "", "")
	if d.title != "Tema Del Track" || d.artist != "Artista Del Track" {
		t.Fatalf("no completó título/artista desde el track: %+v", d)
	}
	if d.isrc != "USRC17607839" || d.spotifyID != "sp" || d.deezerID != "dz" ||
		d.tidalID != "td" || d.qobuzID != "qz" || d.durationMS != 210000 {
		t.Fatalf("no copió la identidad del track: %+v", d)
	}
	if !d.tieneResolucion() {
		t.Fatal("tenía ISRC/ids y tieneResolucion() = false")
	}
	// El llamado del llamador manda sobre el del track.
	if d := identidadDeTrack(track, "Otro Titulo", "Otro Artista"); d.title != "Otro Titulo" || d.artist != "Otro Artista" {
		t.Fatalf("el llamado no ganó: %+v", d)
	}
}

// TestRescueStreamNoRepiteIdentidadYaProbada: la fase exacta del rescate NO
// vuelve a sondear la identidad que la fase de identificadores ya probó (evita
// duplicar carga y 429s); con identidadProbada=false sí resuelve por ISRC.
func TestRescueStreamNoRepiteIdentidadYaProbada(t *testing.T) {
	const isrc = "USRC17607839"
	cooldown.MarkOk("flac-rescue")
	nuevoRegistro := func() *provider.Registry {
		reg := provider.NewRegistry()
		reg.Register(&identStub{
			name:   "flac-rescue",
			track:  &provider.TrackResult{ID: isrc, Title: isrc, ISRC: isrc, Provider: "flac-rescue"},
			stream: "http://arcod/flac",
		})
		return reg
	}
	track := &provider.TrackResult{ISRC: isrc}

	// Sin fase previa: la fase exacta resuelve y gana.
	url, prov, _, _ := rescueStream(nuevoRegistro(), track, "", "", "flac", false)
	if url != "http://arcod/flac" || prov != "flac-rescue" {
		t.Fatalf("la fase exacta debía resolver por ISRC: url=%q prov=%q", url, prov)
	}

	// Con la identidad ya probada arriba: no se repite (no hay otra fase con
	// título/artista vacíos, así que no queda nada por resolver).
	inicio := time.Now()
	url, prov, _, _ = rescueStream(nuevoRegistro(), track, "", "", "flac", true)
	if url != "" || prov != "" {
		t.Fatalf("repitió la identidad ya probada: url=%q prov=%q", url, prov)
	}
	if tardanza := time.Since(inicio); tardanza > time.Second {
		t.Fatalf("la fase exacta no debía lanzarse, y tardó %s", tardanza)
	}
}
