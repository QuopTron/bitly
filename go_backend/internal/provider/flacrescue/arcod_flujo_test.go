package flacrescue

// arcod_flujo_test.go — Fija el FLUJO del canal arcod (buscar el ISRC en el
// catálogo → pedir el enlace del stream) contra un servidor de prueba que imita
// su API, y su comportamiento cuando el sitio se queda sin cuentas.
//
// Por qué aparte de arcod_test.go: ahí vive la lectura y la elección (puro);
// acá, las peticiones que se hacen, con qué parámetros y qué se recuerda.
//
// Nunca sale a Internet.

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
)

// registroArcod junta lo que llegó al servidor de prueba (el handler corre en
// otras goroutines, así que va con candado).
type registroArcod struct {
	mu        sync.Mutex
	busquedas []string
	streams   []string
	cuotas    []string
}

func (r *registroArcod) anotar(lista *[]string, valor string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	*lista = append(*lista, valor)
}

func (r *registroArcod) leer(lista *[]string) []string {
	r.mu.Lock()
	defer r.mu.Unlock()
	return append([]string(nil), *lista...)
}

// clienteArcod arma un cliente con el canal arcod ENCENDIDO y apuntando a
// [srv]: los tests del paquete lo apagan en TestMain (offline por contrato), así
// que el que prueba el canal lo enciende a mano.
func clienteArcod(srv *httptest.Server) *Client {
	c := NewClient()
	c.arcodActivo = true
	c.arcodBase = srv.URL
	return c
}

// servidorArcod imita la API del sitio: el catálogo y el lector de streams.
// [sinCuentas] hace que el catálogo responda como responde cuando su pool de
// tokens está vacío.
func servidorArcod(t *testing.T, sinCuentas bool, registro *registroArcod) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.URL.Path == "/api/v2/guest/rate-limit":
			// El sitio publica su propio presupuesto por IP; el canal lo mira
			// antes de gastar una petición (ver arcod_cuota.go).
			registro.anotar(&registro.cuotas, r.URL.Path)
			_, _ = w.Write([]byte(`{"remaining":999999,"isLimited":false}`))
		case r.URL.Path == "/api/get-music":
			registro.anotar(&registro.busquedas, r.URL.Query().Get("q"))
			if r.URL.Query().Get("offset") == "" {
				t.Error("la búsqueda necesita offset")
			}
			if sinCuentas {
				_, _ = w.Write([]byte(jsonSinCuentasArcod))
				return
			}
			_, _ = w.Write([]byte(jsonCatalogoArcod))
		case strings.HasPrefix(r.URL.Path, "/api/player/stream/"):
			registro.anotar(&registro.streams, r.URL.Path+"?"+r.URL.RawQuery)
			_, _ = w.Write([]byte(jsonStreamArcod))
		default:
			t.Errorf("petición inesperada: %s %s", r.Method, r.URL.Path)
		}
	}))
}

func TestResolverArcodBuscaPorISRCYPideElStream(t *testing.T) {
	registro := &registroArcod{}
	srv := servidorArcod(t, false, registro)
	defer srv.Close()

	cliente := clienteArcod(srv)
	enlace, err := cliente.resolverArcod("QMFMF2447055", "FLAC")
	if err != nil {
		t.Fatalf("debería resolver el stream: %v", err)
	}
	if enlace != "https://api.arcod.xyz/v2/stream/play?t=v1.abc" {
		t.Fatalf("enlace mal devuelto: %q", enlace)
	}
	// La búsqueda va por ISRC (su catálogo lo indexa) y el stream por el id de
	// ESA pista, con la calidad sin pérdida.
	if b := registro.leer(&registro.busquedas); len(b) != 1 || b[0] != "QMFMF2447055" {
		t.Fatalf("debería buscar una sola vez por ISRC: %v", b)
	}
	if s := registro.leer(&registro.streams); len(s) != 1 ||
		!strings.Contains(s[0], "/api/player/stream/312055179") ||
		!strings.Contains(s[0], "quality=6") {
		t.Fatalf("stream mal pedido: %v", s)
	}
}

func TestResolverArcodRecuerdaElIdYNoRepiteLaBusqueda(t *testing.T) {
	registro := &registroArcod{}
	srv := servidorArcod(t, false, registro)
	defer srv.Close()

	cliente := clienteArcod(srv)
	for i := 0; i < 2; i++ {
		if _, err := cliente.resolverArcod("QMFMF2447055", "FLAC"); err != nil {
			t.Fatalf("intento %d: %v", i+1, err)
		}
	}
	// El id de la grabación no cambia: la segunda vez solo se pide el stream.
	if b := registro.leer(&registro.busquedas); len(b) != 1 {
		t.Fatalf("la segunda resolución no debería volver a buscar: %v", b)
	}
}

func TestResolverArcodRechazaQueElSitioBajeLaCalidad(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/api/get-music" {
			_, _ = w.Write([]byte(jsonCatalogoArcod))
			return
		}
		// El sitio degrada a MP3: para un pedido sin pérdida eso es un fallo,
		// así las fuentes que sí pueden dar FLAC siguen teniendo su turno.
		_, _ = w.Write([]byte(`{"url":"https://api.arcod.xyz/v2/stream/play?t=v1.mp3","mimeType":"audio/mpeg"}`))
	}))
	defer srv.Close()

	cliente := clienteArcod(srv)
	if _, err := cliente.resolverArcod("QMFMF2447055", "FLAC"); err == nil {
		t.Fatal("un MP3 no puede pasar por FLAC")
	}
	// Con pérdida pedida, ese mismo MP3 sí sirve.
	if _, err := cliente.resolverArcod("QMFMF2447055", "MP3_320"); err != nil {
		t.Fatalf("con pérdida debería aceptarlo: %v", err)
	}
}

func TestResolverArcodSePausaCuandoElSitioNoTieneCuentas(t *testing.T) {
	registro := &registroArcod{}
	srv := servidorArcod(t, true, registro)
	defer srv.Close()

	cliente := clienteArcod(srv)
	if _, err := cliente.resolverArcod("QMFMF2447055", "FLAC"); err == nil {
		t.Fatal("sin cuentas no puede resolver")
	}
	// El canal queda en pausa: la segunda vez ni se pide (si no, cada canción
	// pagaría la espera de un sitio que no puede responder).
	if _, err := cliente.resolverArcod("QMFMF2447055", "FLAC"); err == nil {
		t.Fatal("en pausa tampoco puede resolver")
	}
	if b := registro.leer(&registro.busquedas); len(b) != 1 {
		t.Fatalf("en pausa no debería volver a pedir: %v", b)
	}
}

func TestGetStreamURLUsaElCanalArcod(t *testing.T) {
	registro := &registroArcod{}
	srv := servidorArcod(t, false, registro)
	defer srv.Close()

	cliente := clienteArcod(srv)
	// Sin espejos: el canal tiene que resolver solo, antes de ellos.
	cliente.mirrors = nil
	enlace, err := cliente.GetStreamURL("QMFMF2447055", "FLAC")
	if err != nil {
		t.Fatalf("debería resolver por el canal arcod: %v", err)
	}
	if !strings.Contains(enlace, "/v2/stream/play") {
		t.Fatalf("enlace inesperado: %q", enlace)
	}
	// La segunda vez sale de la caché: cero peticiones más.
	antes := len(registro.leer(&registro.busquedas))
	if _, err := cliente.GetStreamURL("QMFMF2447055", "FLAC"); err != nil {
		t.Fatalf("la segunda vez debería salir de la caché: %v", err)
	}
	if ahora := len(registro.leer(&registro.busquedas)); ahora != antes {
		t.Fatalf("la caché debería evitar la búsqueda: %d → %d", antes, ahora)
	}
}
