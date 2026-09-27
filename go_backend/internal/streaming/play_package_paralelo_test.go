package streaming

import (
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// pkgStubProvider es un proveedor con cada eslabón controlable por separado.
// Hace falta para el paralelismo de la metadata: hay que poder dejar LENTA (o
// colgada) la fase de identidad y RÁPIDA la resolución del audio, que es
// exactamente el escenario que este cambio resuelve.
type pkgStubProvider struct {
	name    string
	track   *provider.TrackResult
	buscar  func(q string) ([]provider.TrackResult, error)
	porISRC func(isrc string) (*provider.TrackResult, error)
	trackFn func(id string) (*provider.TrackResult, error)
	resolve func(id string) (string, error)
}

func (s *pkgStubProvider) Name() string { return s.name }
func (s *pkgStubProvider) SearchTracks(q string, l int) ([]provider.TrackResult, error) {
	if s.buscar != nil {
		return s.buscar(q)
	}
	return nil, nil
}
func (s *pkgStubProvider) SearchAlbums(q string, l int) ([]provider.AlbumResult, error) {
	return nil, nil
}
func (s *pkgStubProvider) SearchArtists(q string, l int) ([]provider.ArtistResult, error) {
	return nil, nil
}
func (s *pkgStubProvider) SearchPlaylists(q string, l int) ([]provider.PlaylistResult, error) {
	return nil, nil
}
func (s *pkgStubProvider) GetTrack(id string) (*provider.TrackResult, error) {
	if s.trackFn != nil {
		return s.trackFn(id)
	}
	return s.track, nil
}
func (s *pkgStubProvider) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	if s.porISRC != nil {
		return s.porISRC(isrc)
	}
	return s.track, nil
}
func (s *pkgStubProvider) GetAlbum(id string) (*provider.AlbumResult, error) { return nil, nil }
func (s *pkgStubProvider) GetArtist(id string) (*provider.ArtistResult, error) {
	return nil, nil
}
func (s *pkgStubProvider) GetStreamURL(id, quality string) (string, error) {
	if s.resolve != nil {
		return s.resolve(id)
	}
	return "", nil
}

// Regresión del bug de latencia: la metadata era un paso SERIAL delante del
// stream, así que su tiempo entero se sumaba al pedido. Medido con el arnés real
// (amazon→Percuma): 2,49s de metadata + 2,22s de rescate = 4,71s cuando el audio
// ya estaba a los 2,22s. Acá los dos eslabones de la metadata (la búsqueda del
// proveedor preferido y las fases cruzadas) se quedan COLGADOS a propósito,
// mientras que el atajo del proveedor preferido resuelve el audio al instante:
// el pedido tiene que salir igual.
func TestMetadataNoBloqueaElStream(t *testing.T) {
	cooldown.MarkOk("youtube")
	cooldown.MarkOk("soundcloud")

	cuelga := make(chan struct{})
	defer close(cuelga) // libera a los workers colgados para que el proceso termine.

	esperar := func() { <-cuelga }
	const isrc = "TESTPP0000001"
	track := &provider.TrackResult{
		ID: "abc", Title: "T", Artist: "A", ISRC: isrc, Duration: 180000,
	}

	reg := provider.NewRegistry()
	// El ganador del audio: verifica con GetTrack y resuelve al instante. Su
	// fase de IDENTIDAD (GetTrackByISRC) se queda colgada, que es justo lo que
	// la metadata usa y el atajo no.
	reg.Register(&pkgStubProvider{
		name:    "youtube",
		track:   track,
		porISRC: func(string) (*provider.TrackResult, error) { esperar(); return nil, nil },
		resolve: func(string) (string, error) { return "http://yt/stream", nil },
	})
	// Segundo proveedor de AUDIO, pero con todo colgado: es el que hace que las
	// fases cruzadas de la metadata se queden esperando su presupuesto entero
	// (900ms por ISRC + 1200ms por nombre) en vez de volver al instante.
	reg.Register(&pkgStubProvider{
		name:    "soundcloud",
		buscar:  func(string) ([]provider.TrackResult, error) { esperar(); return nil, nil },
		porISRC: func(string) (*provider.TrackResult, error) { esperar(); return nil, nil },
	})

	inicio := time.Now()
	pkg, err := GetStreamPackage(reg, nil, "youtube", "abc", "high", false,
		"T", "A", "", isrc, "", "", "", "", 180000)
	transcurrido := time.Since(inicio)

	if err != nil || pkg == nil {
		t.Fatalf("el atajo del proveedor preferido debía resolver el stream: pkg=%v err=%v", pkg, err)
	}
	if pkg.AudioURL != "http://yt/stream" || pkg.Provider != "youtube" {
		t.Fatalf("stream inesperado: url=%q prov=%q", pkg.AudioURL, pkg.Provider)
	}
	// La metadata sola tarda ~2,5s (400ms + 900ms + 1200ms de presupuesto). Si el
	// pedido la esperara —como antes— este margen no alcanzaría ni de lejos.
	if transcurrido > 1200*time.Millisecond {
		t.Fatalf("el pedido tardó %s con la metadata colgada; el stream estaba listo de inmediato", transcurrido)
	}
	// Y la prueba de que la metadata NO se esperó: seguía en vuelo al salir el
	// paquete, así que no pudo completarlo (tampoco el respaldo por nombre, que
	// este proveedor no devuelve).
	if pkg.Track != nil {
		t.Fatalf("pkg.Track=%+v: la metadata no había terminado, no puede venir de ella", pkg.Track)
	}
}

// La metadata ya resuelta para este pedido (tap repetido, prefetch, vecino de
// cola) se cosecha SIN abrir ninguna ventana: el paquete sale con los datos
// ricos del proveedor y el pedido no paga el presupuesto de la fase. Era gratis
// por construcción cuando la fase era serial; el riesgo del paralelismo era
// perderla y volver a buscar por nombre en cada tap repetido.
func TestMetadataCacheadaLlenaElPaqueteSinEsperar(t *testing.T) {
	cooldown.MarkOk("youtube")
	const isrc = "TESTPP0000002"
	track := &provider.TrackResult{
		ID: "cache", Title: "Cancion-cache", Artist: "Artista-cache", ISRC: isrc, Duration: 200000,
	}
	reg := provider.NewRegistry()
	reg.Register(&pkgStubProvider{
		name:    "youtube",
		track:   track,
		resolve: func(string) (string, error) { return "http://yt/cache", nil },
	})

	pedido := func() (*StreamPackage, error) {
		return GetStreamPackage(reg, nil, "youtube", "cache", "high", false,
			"Cancion-cache", "Artista-cache", "", isrc, "", "", "", "", 200000)
	}
	if _, err := pedido(); err != nil {
		t.Fatalf("primer pedido (resuelve y cachea): %v", err)
	}

	inicio := time.Now()
	pkg, err := pedido()
	transcurrido := time.Since(inicio)
	if err != nil || pkg == nil {
		t.Fatalf("segundo pedido: pkg=%v err=%v", pkg, err)
	}
	if pkg.Track == nil || pkg.Track.Title != "Cancion-cache" {
		t.Fatalf("la metadata cacheada debía llenar pkg.Track: %+v", pkg.Track)
	}
	if transcurrido > 250*time.Millisecond {
		t.Fatalf("el pedido ya cacheado tardó %s: la cosecha no puede abrir ventana", transcurrido)
	}
}

// La metadata que llega DESPUÉS del stream pero dentro de la gracia igual
// completa el paquete. Es la que evita el peor final: que el paquete salga sin
// track y dispare una búsqueda por nombre nueva (1-3s) justo después de haber
// resuelto la reproducción.
func TestMetadataTardiaCompletaElPaquete(t *testing.T) {
	cooldown.MarkOk("youtube")
	const isrc = "TESTPP0000003"
	track := &provider.TrackResult{
		ID: "tarde", Title: "Cancion-tarde", Artist: "Artista-tarde", ISRC: isrc, Duration: 150000,
	}
	reg := provider.NewRegistry()
	reg.Register(&pkgStubProvider{
		name:  "youtube",
		track: track,
		// La fase de metadata tarda más que el audio, pero cae dentro de la gracia.
		porISRC: func(string) (*provider.TrackResult, error) {
			time.Sleep(esperaMetadataTardia / 2)
			return track, nil
		},
		resolve: func(string) (string, error) { return "http://yt/tarde", nil },
	})

	pkg, err := GetStreamPackage(reg, nil, "youtube", "tarde", "high", false,
		"Cancion-tarde", "Artista-tarde", "", isrc, "", "", "", "", 150000)
	if err != nil || pkg == nil {
		t.Fatalf("pedido: pkg=%v err=%v", pkg, err)
	}
	if pkg.AudioURL != "http://yt/tarde" {
		t.Fatalf("stream inesperado: %q", pkg.AudioURL)
	}
	if pkg.Track == nil || pkg.Track.Title != "Cancion-tarde" {
		t.Fatalf("la metadata que llegó tarde debía completar el paquete: %+v", pkg.Track)
	}
}
