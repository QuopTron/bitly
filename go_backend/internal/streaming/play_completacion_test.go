package streaming

import (
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// acortarEsperaCompletacion deja la gracia de la completación en [d] y la
// devuelve al terminar el test (es un var justamente para esto).
func acortarEsperaCompletacion(t *testing.T, d time.Duration) {
	t.Helper()
	previo := esperaCompletacionTardia
	esperaCompletacionTardia = d
	t.Cleanup(func() { esperaCompletacionTardia = previo })
}

// Regresión del cuello de recta final: el audio estaba resuelto y el paquete
// seguía esperando a una búsqueda por nombre SIN techo antes de devolver.
// Medido en el arnés real (ítem de feed): "stream listo 354ms", pero el pedido
// salía a los 1528ms — el 1,2s restante era exactamente esta completación.
//
// Acá la identidad no resuelve (la metadata sale vacía), así que el paquete
// cae a la completación por nombre, que además está colgada: el pedido tiene
// que salir dentro de su gracia igual.
func TestCompletacionTardiaNoRetrasaElPaquete(t *testing.T) {
	cooldown.MarkOk("youtube")
	acortarEsperaCompletacion(t, 150*time.Millisecond)

	const isrc = "TESTPP0000004"
	lenta := make(chan struct{})
	// Se libera al final para no dejar colgada a la goroutine de fondo.
	t.Cleanup(func() { close(lenta) })

	reg := provider.NewRegistry()
	reg.Register(&pkgStubProvider{
		name: "youtube",
		// La identidad no resuelve: ni por ISRC ni por id, y la búsqueda por
		// nombre tarda más que cualquier gracia (la metadata y la completación
		// las dos se cortan, que es justo lo que se mide acá).
		porISRC: func(string) (*provider.TrackResult, error) { return nil, nil },
		trackFn: func(string) (*provider.TrackResult, error) { return nil, nil },
		buscar: func(string) ([]provider.TrackResult, error) {
			select {
			case <-lenta:
			case <-time.After(3 * time.Second):
			}
			return []provider.TrackResult{{ID: "tardio", Title: "Tardia", Artist: "A", ISRC: isrc}}, nil
		},
		resolve: func(string) (string, error) { return "http://yt/listo", nil },
	})

	inicio := time.Now()
	pkg, err := GetStreamPackage(reg, nil, "youtube", "tardio", "high", false,
		"Tardia", "A", "", isrc, "", "", "", "", 150000)
	transcurrido := time.Since(inicio)

	if err != nil || pkg == nil {
		t.Fatalf("el stream debía resolverse: pkg=%v err=%v", pkg, err)
	}
	if pkg.AudioURL != "http://yt/listo" {
		t.Fatalf("stream inesperado: %q", pkg.AudioURL)
	}
	if pkg.Track != nil {
		t.Fatalf("pkg.Track=%+v: la completación estaba colgada, no puede venir de ella", pkg.Track)
	}
	// Gracia de la metadata (300ms) + gracia de la completación, con margen.
	if transcurrido > 800*time.Millisecond {
		t.Fatalf("el paquete tardó %s: la completación lo siguió bloqueando", transcurrido)
	}
}

// La búsqueda por nombre que RESPONDE deja su resultado en la caché de
// metadata: el siguiente pedido de esta misma canción encuentra el track sin
// volver a buscar (que era para lo que existía la completación en serie).
func TestBuscarTrackPorNombreCacheaElResultado(t *testing.T) {
	const isrc = "TESTPP0000005"
	clave := claveCacheMetadata(isrc, "", "", "", "", "", "Completa", "A")
	// La clave del test anterior puede haber dejado basura: se parte de la
	// identidad de ESTE test y de la caché limpia para no depender del orden.
	t.Cleanup(func() {
		metaMu.Lock()
		delete(metaCache, clave)
		metaMu.Unlock()
	})

	track := &provider.TrackResult{ID: "completa", Title: "Completa", Artist: "A", ISRC: isrc}
	reg := provider.NewRegistry()
	reg.Register(&pkgStubProvider{
		name: "youtube",
		buscar: func(string) ([]provider.TrackResult, error) {
			return []provider.TrackResult{*track}, nil
		},
	})

	encontrado := buscarTrackPorNombre(reg, "youtube", clave, "Completa", "A")
	if encontrado == nil || encontrado.Title != "Completa" {
		t.Fatalf("la búsqueda no devolvió el track: %+v", encontrado)
	}
	if cacheada := metadataCacheada(clave); cacheada == nil || cacheada.Title != "Completa" {
		t.Fatalf("la búsqueda debe dejar su resultado en la caché (clave %q): %+v", clave, cacheada)
	}
}
