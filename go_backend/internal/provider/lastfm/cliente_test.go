package lastfm

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// paginaFalsa es un HTML mínimo con una fila real de pista.
const paginaFalsa = `<html><body>data-scrobble-row
<a data-youtube-id="KU5V5WZVcVE" data-track-name="NUEVAYoL" data-artist-name="Bad Bunny">x</a>
<td class="chartlist-duration">3:02</td></body></html>`

func TestCargar_CacheaYNoRepiteLaPeticion(t *testing.T) {
	var pedidos int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		atomic.AddInt32(&pedidos, 1)
		_, _ = w.Write([]byte(paginaFalsa))
	}))
	defer srv.Close()

	c := nuevoConBase(srv.URL, srv.Client())
	for i := 0; i < 3; i++ {
		if _, err := c.cargar("/music/Bad+Bunny/DeB%C3%8D+TiRAR+M%C3%A1S+FOToS"); err != nil {
			t.Fatalf("carga %d: %v", i, err)
		}
	}
	if got := atomic.LoadInt32(&pedidos); got != 1 {
		t.Fatalf("se esperaba UNA petición al sitio, hubo %d", got)
	}
}

func TestCargar_UnSoloVueloPorPagina(t *testing.T) {
	var pedidos int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		atomic.AddInt32(&pedidos, 1)
		time.Sleep(150 * time.Millisecond)
		_, _ = w.Write([]byte(paginaFalsa))
	}))
	defer srv.Close()

	c := nuevoConBase(srv.URL, srv.Client())
	var wg sync.WaitGroup
	for i := 0; i < 6; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_, _ = c.cargar("/music/Bad+Bunny/+tracks")
		}()
	}
	wg.Wait()
	if got := atomic.LoadInt32(&pedidos); got != 1 {
		t.Fatalf("seis pedidos simultáneos debían salir como UNO, hubo %d", got)
	}
}

func TestCargar_DesafioPausaElSitioYNoReintenta(t *testing.T) {
	var pedidos int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		atomic.AddInt32(&pedidos, 1)
		_, _ = w.Write([]byte(`<!DOCTYPE html><html><head><title>Client Challenge</title></head></html>`))
	}))
	defer srv.Close()

	c := nuevoConBase(srv.URL, srv.Client())
	if _, err := c.cargar("/music/Bad+Bunny"); !errors.Is(err, ErrEnPausa) {
		t.Fatalf("se esperaba ErrEnPausa, llegó %v", err)
	}
	if !c.EnPausa() {
		t.Fatal("el sitio debería quedar en pausa tras el desafío")
	}
	// Y no se vuelve a molestar al sitio durante la pausa.
	if _, err := c.cargar("/music/Bad+Bunny/+tracks"); !errors.Is(err, ErrEnPausa) {
		t.Fatalf("en pausa debería devolver ErrEnPausa, llegó %v", err)
	}
	if got := atomic.LoadInt32(&pedidos); got != 1 {
		t.Fatalf("no debía reintentar durante la pausa, hubo %d peticiones", got)
	}
}

func TestEsDesafio(t *testing.T) {
	if !esDesafio(`<html><title>Client Challenge</title></html>`) {
		t.Fatal("el título del desafío debe reconocerse")
	}
	if !esDesafio("respuesta diminuta sin html") {
		t.Fatal("una respuesta diminuta sin html debe tratarse como desafío")
	}
	if esDesafio(paginaFalsa) {
		t.Fatal("una página real no es un desafío")
	}
}

func TestPistas_CacheDeArtistaNoRepitePeticion(t *testing.T) {
	var pedidos int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&pedidos, 1)
		if r.URL.Path != "/music/Bad+Bunny/+tracks" {
			t.Errorf("ruta inesperada: %s", r.URL.Path)
		}
		_, _ = w.Write([]byte(paginaFalsa))
	}))
	defer srv.Close()

	c := nuevoConBase(srv.URL, srv.Client())
	for i := 0; i < 2; i++ {
		pistas, err := c.PistasDeArtista("Bad Bunny")
		if err != nil {
			t.Fatalf("pistas: %v", err)
		}
		if len(pistas) != 1 || pistas[0].YouTubeID != "KU5V5WZVcVE" {
			t.Fatalf("pistas inesperadas: %+v", pistas)
		}
	}
	if got := atomic.LoadInt32(&pedidos); got != 1 {
		t.Fatalf("debía salir de caché la segunda vez, hubo %d peticiones", got)
	}
}

func TestMejorCoincidencia_UsaElAlbumYVerifica(t *testing.T) {
	var rutas []string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Se apunta la ruta pedida: la primera consulta debe ser la del ÁLBUM
		// (bloque más barato y el que trae las duraciones).
		rutas = append(rutas, r.URL.Path)
		_, _ = w.Write([]byte(paginaFalsa))
	}))
	defer srv.Close()

	c := nuevoConBase(srv.URL, srv.Client())
	pista, err := c.MejorCoincidencia("Bad Bunny", "DeBÍ TiRAR MáS FOToS", "NUEVAYoL", 183000)
	if err != nil {
		t.Fatalf("MejorCoincidencia: %v", err)
	}
	if pista == nil || pista.YouTubeID != "KU5V5WZVcVE" {
		t.Fatalf("no encontró la pista del álbum: %+v", pista)
	}
	if len(rutas) == 0 || !strings.Contains(rutas[0], "/music/Bad+Bunny/DeB") {
		t.Fatalf("la primera consulta debía ser la del álbum, fue %v", rutas)
	}
	// Un título que no está en el álbum no debe devolver cualquier cosa.
	otra, err := c.MejorCoincidencia("Bad Bunny", "DeBÍ TiRAR MáS FOToS", "Otra Cosa", 0)
	if err != nil || otra != nil {
		t.Fatalf("devolvió una coincidencia que no existe: %+v (err %v)", otra, err)
	}
}
