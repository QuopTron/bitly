package flacrescue

// arcod_propia_test.go — Prueba de punta a punta del SEGUNDO CANAL con una
// instancia PROPIA de arcod (ver selfhost/arcod/README.md).
//
// Por qué existe: la instancia PÚBLICA de arcod está muerta en el ORIGEN —su pool
// de tokens de Qobuz está vacío y contesta 500 "No healthy Qobuz tokens
// available" para cualquier ISRC—, así que el canal no se puede comprobar contra
// ella. Lo que sí se puede comprobar, y es lo que decide si vale la pena
// levantarse una instancia propia, es que el CÓDIGO la usa bien: la misma API
// detrás de un Bearer, con el contrato exacto del README (rate-limit, catálogo
// por ISRC y la ruta del stream), y que el enlace entregado sea un FLAC de
// verdad con Range.
//
// Nunca sale a Internet: la instancia es un servidor local.

import (
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"sync"
	"testing"
)

// tokenArcodPropio es el JWT que el README pide cuando la instancia exige sesión
// (STREAM_GUEST_QUALITY=5).
const tokenArcodPropio = "jwt-de-prueba"

// flacDePrueba son los primeros bytes de un FLAC real ("fLaC") más relleno: lo
// que importa es que el reproductor reciba audio, no una página de error.
var flacDePrueba = append([]byte("fLaC"), make([]byte, 64)...)

// vistosArcod recuerda con qué Bearer llegó cada ruta (el handler corre en otras
// goroutines).
type vistosArcod struct {
	mu      sync.Mutex
	valores map[string]string
	veces   map[string]int
}

func (v *vistosArcod) anotar(ruta, auth string) {
	v.mu.Lock()
	defer v.mu.Unlock()
	v.valores[ruta] = auth
	v.veces[ruta]++
}

func (v *vistosArcod) bearer(ruta string) string {
	v.mu.Lock()
	defer v.mu.Unlock()
	return v.valores[ruta]
}

func (v *vistosArcod) visitas(ruta string) int {
	v.mu.Lock()
	defer v.mu.Unlock()
	return v.veces[ruta]
}

// servirArcodPropio imita el contrato del README para una instancia propia.
// [rutaStream] permite probar las dos puertas conocidas: la que usa la pública
// ("/api/player/stream/") y la que trae el repo abierto ("/v2/stream/").
func servirArcodPropio(t *testing.T, rutaStream string, vistos *vistosArcod) *httptest.Server {
	t.Helper()
	var srv *httptest.Server
	srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.URL.Path == "/api/v2/guest/rate-limit":
			// La instancia publica su propio presupuesto; el canal lo mira antes
			// de gastar una petición (ver arcod_cuota.go).
			_, _ = w.Write([]byte(`{"remaining":999999,"isLimited":false}`))
		case r.URL.Path == "/api/get-music":
			// El catálogo se busca por ISRC, igual que en la pública.
			if q := r.URL.Query().Get("q"); q != "QMFMF2447055" {
				t.Errorf("la búsqueda debería ir por ISRC, fue por %q", q)
			}
			_, _ = w.Write([]byte(jsonCatalogoArcod))
		case strings.HasPrefix(r.URL.Path, "/api/player/stream/"),
			strings.HasPrefix(r.URL.Path, "/v2/stream/"):
			if !strings.HasPrefix(r.URL.Path, rutaStream) {
				// La puerta que esta instancia NO expone: se comporta como el 404
				// que daría el repo abierto con la ruta que no trae. El canal
				// tiene que seguir probando la siguiente.
				vistos.anotar("/api/player/stream/", r.Header.Get("Authorization"))
				w.WriteHeader(http.StatusNotFound)
				return
			}
			vistos.anotar(rutaStream, r.Header.Get("Authorization"))
			// La puerta del stream exige sesión: es el punto entero de
			// arcod_token.
			if r.Header.Get("Authorization") != "Bearer "+tokenArcodPropio {
				w.WriteHeader(http.StatusForbidden)
				_, _ = w.Write([]byte(`{"error":"sesión requerida"}`))
				return
			}
			if q := r.URL.Query().Get("quality"); q != "6" {
				t.Errorf("un pedido sin pérdida tiene que pedir quality=6, pidió %q", q)
			}
			w.Header().Set("content-type", "application/json")
			fmt.Fprintf(w, `{"url":%q,"mimeType":"audio/flac","quality":6,"trackId":"312055179"}`,
				srv.URL+"/cdn/audio.flac?t=v1")
		case r.URL.Path == "/cdn/audio.flac":
			// El audio, con Range: sin Range el reproductor tendría que bajar la
			// canción entera antes de sonar.
			w.Header().Set("Content-Type", "audio/flac")
			w.Header().Set("Accept-Ranges", "bytes")
			inicio, fin := 0, len(flacDePrueba)
			if rango := r.Header.Get("Range"); rango != "" {
				var a, b int
				if _, err := fmt.Sscanf(rango, "bytes=%d-%d", &a, &b); err == nil {
					inicio, fin = a, b+1
					if fin > len(flacDePrueba) {
						fin = len(flacDePrueba)
					}
				}
			}
			trozo := flacDePrueba[inicio:fin]
			w.Header().Set("Content-Length", strconv.Itoa(len(trozo)))
			if r.Header.Get("Range") != "" {
				w.WriteHeader(http.StatusPartialContent)
			}
			_, _ = w.Write(trozo)
		default:
			t.Errorf("petición inesperada: %s %s", r.Method, r.URL.Path)
		}
	}))
	t.Cleanup(srv.Close)
	return srv
}

// clienteArcodPropio arma el cliente como lo hace el usuario en Ajustes →
// Credenciales: `arcod` con la URL de su instancia y `arcod_token` con su JWT.
func clienteArcodPropio(t *testing.T, srv *httptest.Server, vistos *vistosArcod) *Client {
	t.Helper()
	// La comprobación del enlace es la REAL (TestMain la sustituye por un "sí" en
	// todo el paquete): con una instancia propia interesa comprobarla de verdad.
	original := comprobarEnlaceArcod
	comprobarEnlaceArcod = enlaceArcodSirveAudio
	t.Cleanup(func() { comprobarEnlaceArcod = original })

	c := NewClient()
	c.aplicarAjusteArcod(map[string]string{
		"arcod":         srv.URL,
		claveTokenArcod: tokenArcodPropio,
	})
	// Sin espejos: el canal tiene que resolver solo (y el test queda offline).
	c.mirrors = nil
	return c
}

// TestInstanciaArcodPropiaResuelveConBearer: el canal completo contra una
// instancia propia —presupuesto, catálogo por ISRC y la puerta del stream
// detrás del Bearer— y el enlace entregado tiene que ser un FLAC con Range.
func TestInstanciaArcodPropiaResuelveConBearer(t *testing.T) {
	vistos := &vistosArcod{valores: map[string]string{}, veces: map[string]int{}}
	srv := servirArcodPropio(t, "/api/player/stream/", vistos)
	c := clienteArcodPropio(t, srv, vistos)

	enlace, err := c.GetStreamURL("QMFMF2447055", "FLAC")
	if err != nil {
		t.Fatalf("una instancia propia debería resolver el FLAC: %v", err)
	}
	if !strings.Contains(enlace, "/cdn/audio.flac") {
		t.Fatalf("enlace inesperado: %q", enlace)
	}
	// El Bearer no es decorativo: la instancia lo exige para el stream.
	if got := vistos.bearer("/api/player/stream/"); got != "Bearer "+tokenArcodPropio {
		t.Fatalf("el stream no llevó el Bearer de la instancia, llevó %q", got)
	}

	// Y el enlace entrega FLAC de verdad, por tramos.
	req, err := http.NewRequest(http.MethodGet, enlace, nil)
	if err != nil {
		t.Fatalf("no se pudo armar la petición: %v", err)
	}
	req.Header.Set("Range", "bytes=0-3")
	resp, err := (&http.Client{}).Do(req)
	if err != nil {
		t.Fatalf("no se pudo abrir el enlace: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusPartialContent {
		t.Fatalf("el enlace no soporta Range: status %d", resp.StatusCode)
	}
	cabecera := make([]byte, 4)
	if _, err := io.ReadFull(resp.Body, cabecera); err != nil {
		t.Fatalf("no se pudo leer la cabecera: %v", err)
	}
	if string(cabecera) != "fLaC" {
		t.Fatalf("el enlace no entrega FLAC (cabecera %q)", cabecera)
	}
	t.Logf("instancia propia: FLAC con Range y Bearer, enlace %.60s…", enlace)
}

// TestInstanciaArcodPropiaUsaSuPuertaDeStream: el repo abierto expone la ruta
// del stream en OTRO lado ("/v2/stream/"). El README promete que no hay que
// decirle cuál usa la instancia: el canal prueba las puertas conocidas, se queda
// con la que responde y la recuerda — así las canciones siguientes pagan UNA
// sola petición en vez de intentar la que no está.
func TestInstanciaArcodPropiaUsaSuPuertaDeStream(t *testing.T) {
	vistos := &vistosArcod{valores: map[string]string{}, veces: map[string]int{}}
	srv := servirArcodPropio(t, "/v2/stream/", vistos)
	c := clienteArcodPropio(t, srv, vistos)

	enlace, err := c.GetStreamURL("QMFMF2447055", "FLAC")
	if err != nil {
		t.Fatalf("debería encontrar la puerta que su instancia sí expone: %v", err)
	}
	if !strings.Contains(enlace, "/cdn/audio.flac") {
		t.Fatalf("enlace inesperado: %q", enlace)
	}
	if got := vistos.bearer("/v2/stream/"); got != "Bearer "+tokenArcodPropio {
		t.Fatalf("la puerta del repo no llevó el Bearer, llevó %q", got)
	}
	// La puerta que NO está se intentó una sola vez; la que funciona queda
	// memorizada (ver arcod_stream.go).
	fallidas := vistos.visitas("/api/player/stream/")
	if fallidas != 1 {
		t.Fatalf("la puerta ausente debería intentarse una sola vez, se intentó %d", fallidas)
	}
	t.Logf("puerta /v2/stream/ detectada y recordada (la ausente se intentó %d vez)", fallidas)
}
