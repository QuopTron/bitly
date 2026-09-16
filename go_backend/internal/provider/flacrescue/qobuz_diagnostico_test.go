package flacrescue

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
)

// pistaFalsa es una respuesta de /catalog/search con una pista con id.
const pistaFalsa = `{"tracks":{"items":[{"id":123456,"title":"Prueba","isrc":"US1234567890"}]}}`

// servidorQobuzFalso levanta un Qobuz de mentira que responde las dos rutas
// del canal y cuenta las peticiones. [buscaryArchivo] deciden cada respuesta.
func servidorQobuzFalso(t *testing.T, busqueda, archivo http.HandlerFunc) (*httptest.Server, *int32) {
	t.Helper()
	var llamadas int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&llamadas, 1)
		switch {
		case strings.Contains(r.URL.Path, "/catalog/search"):
			busqueda(w, r)
		case strings.Contains(r.URL.Path, "/track/getFileUrl"):
			archivo(w, r)
		default:
			http.NotFound(w, r)
		}
	}))
	t.Cleanup(srv.Close)
	return srv, &llamadas
}

// responderJson escribe un 200 con [cuerpo].
func responderJson(cuerpo string) http.HandlerFunc {
	return func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(cuerpo))
	}
}

// responderCodigo devuelve solo el código, sin cuerpo útil.
func responderCodigo(codigo int) http.HandlerFunc {
	return func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(codigo)
	}
}

// sinOrigenesPorDefecto deja el cliente sin orígenes de fábrica durante el
// test y los restaura al terminar (los defaults apuntan a Internet: un test
// nunca debe tocarlos).
func sinOrigenesPorDefecto(t *testing.T) {
	t.Helper()
	previos := defaultKeysURLs
	defaultKeysURLs = nil
	t.Cleanup(func() { defaultKeysURLs = previos })
}

// TestDiagnosticoSinClavesNoTocaLaRed fija lo más importante del canal: sin
// credenciales NI orígenes por defecto NO se paga ni una petición.
func TestDiagnosticoSinClavesNoTocaLaRed(t *testing.T) {
	sinOrigenesPorDefecto(t)
	srv, llamadas := servidorQobuzFalso(t, responderCodigo(http.StatusInternalServerError), responderCodigo(http.StatusInternalServerError))
	c := NewClient()
	c.SetSettingsQobuz(map[string]string{"qobuz_api_base": srv.URL})

	diag := c.DiagnosticoQobuz()
	if diag.Estado != EstadoSinClaves {
		t.Fatalf("estado = %q, se esperaba %q", diag.Estado, EstadoSinClaves)
	}
	if diag.Fuente != "por_defecto" {
		t.Errorf("fuente = %q, se esperaba por_defecto", diag.Fuente)
	}
	if n := atomic.LoadInt32(llamadas); n != 0 {
		t.Errorf("se hicieron %d peticiones sin credenciales, se esperaban 0", n)
	}
}

// TestDiagnosticoClavesValidasPeroMp3 fija el caso que el usuario cree que
// anda: las claves públicas funcionan pero Qobuz entrega MP3, no FLAC.
func TestDiagnosticoClavesValidasPeroMp3(t *testing.T) {
	mp3 := `{"url":"https://cdn.example/x.mp3","mime_type":"audio/mpeg","restrictions":[{"code":"UserUnauthenticated"}]}`
	srv, _ := servidorQobuzFalso(t, responderJson(pistaFalsa), responderJson(mp3))
	c := NewClient()
	c.SetSettingsQobuz(map[string]string{
		"qobuz_api_base":   srv.URL,
		"qobuz_app_id":     "712109809",
		"qobuz_app_secret": "589be8",
	})

	diag := c.DiagnosticoQobuz()
	if diag.Estado != EstadoMp3 {
		t.Fatalf("estado = %q, se esperaba %q (detalle: %s)", diag.Estado, EstadoMp3, diag.Detalle)
	}
	if diag.Formato != "MP3_320" {
		t.Errorf("formato = %q, se esperaba MP3_320", diag.Formato)
	}
	if diag.Fuente != "manual" {
		t.Errorf("fuente = %q, se esperaba manual", diag.Fuente)
	}
	if !strings.Contains(diag.Detalle, "token") {
		t.Errorf("el detalle debería explicar que falta el token: %q", diag.Detalle)
	}
}

// TestDiagnosticoFlacReal fija el caso bueno: con credenciales que sí sirven.
func TestDiagnosticoFlacReal(t *testing.T) {
	flac := `{"url":"https://cdn.example/x.flac","mime_type":"audio/flac"}`
	srv, _ := servidorQobuzFalso(t, responderJson(pistaFalsa), responderJson(flac))
	c := NewClient()
	c.SetSettingsQobuz(map[string]string{
		"qobuz_api_base":   srv.URL,
		"qobuz_app_id":     "1",
		"qobuz_app_secret": "2",
		"qobuz_user_token": "token-de-suscriptor",
	})

	diag := c.DiagnosticoQobuz()
	if diag.Estado != EstadoFlac || diag.Formato != "FLAC" {
		t.Fatalf("estado/formato = %q/%q, se esperaba flac/FLAC", diag.Estado, diag.Formato)
	}
}

// TestDiagnosticoFirmaRechazada fija el síntoma exacto de un secreto rotado.
func TestDiagnosticoFirmaRechazada(t *testing.T) {
	srv, _ := servidorQobuzFalso(t, responderCodigo(http.StatusUnauthorized), responderJson(`{}`))
	c := NewClient()
	c.SetSettingsQobuz(map[string]string{
		"qobuz_api_base":   srv.URL,
		"qobuz_app_id":     "1",
		"qobuz_app_secret": "viejo",
	})

	if diag := c.DiagnosticoQobuz(); diag.Estado != EstadoFirmaRechazada {
		t.Fatalf("estado = %q, se esperaba %q", diag.Estado, EstadoFirmaRechazada)
	}
}

// TestDiagnosticoServicioCaidoNoEsFirmaRechazada separa "no responde" de
// "la firma no sirve": son dos arreglos distintos para el usuario.
func TestDiagnosticoServicioCaidoNoEsFirmaRechazada(t *testing.T) {
	srv, _ := servidorQobuzFalso(t, responderCodigo(http.StatusInternalServerError), responderJson(`{}`))
	c := NewClient()
	c.SetSettingsQobuz(map[string]string{
		"qobuz_api_base":   srv.URL,
		"qobuz_app_id":     "1",
		"qobuz_app_secret": "2",
	})

	if diag := c.DiagnosticoQobuz(); diag.Estado != EstadoSinConexion {
		t.Fatalf("estado = %q, se esperaba %q", diag.Estado, EstadoSinConexion)
	}
}

// TestOrigenPorDefectoSeUsaSoloSiNoHayNadaConfigurado fija el punto del
// diseño: recién instalada, la app consigue las claves SOLA (sin que el usuario
// pegue nada) y el informe lo dice.
func TestOrigenPorDefectoSeUsaSoloSiNoHayNadaConfigurado(t *testing.T) {
	claves := httptest.NewServer(responderJson(`{"appId":"712109809","appSecret":"589be8"}`))
	t.Cleanup(claves.Close)
	previos := defaultKeysURLs
	defaultKeysURLs = []string{claves.URL}
	t.Cleanup(func() { defaultKeysURLs = previos })

	flac := `{"url":"https://cdn.example/x.flac","mime_type":"audio/flac"}`
	srv, _ := servidorQobuzFalso(t, responderJson(pistaFalsa), responderJson(flac))

	c := NewClient()
	c.SetSettingsQobuz(map[string]string{"qobuz_api_base": srv.URL})

	diag := c.DiagnosticoQobuz()
	if diag.Estado != EstadoFlac {
		t.Fatalf("estado = %q, se esperaba %q (detalle: %s)", diag.Estado, EstadoFlac, diag.Detalle)
	}
	if diag.Fuente != "por_defecto" {
		t.Errorf("fuente = %q, se esperaba por_defecto", diag.Fuente)
	}
}

// TestDiagnosticoDesdeOrigenDeClaves recorre el camino configurable: las
// claves salen de una URL y el informe lo refleja.
func TestDiagnosticoDesdeOrigenDeClaves(t *testing.T) {
	claves := httptest.NewServer(responderJson(`{"appId":"712109809","appSecret":"589be8"}`))
	t.Cleanup(claves.Close)

	flac := `{"url":"https://cdn.example/x.flac","mime_type":"audio/flac"}`
	srv, _ := servidorQobuzFalso(t, responderJson(pistaFalsa), responderJson(flac))

	c := NewClient()
	c.SetSettingsQobuz(map[string]string{
		"qobuz_api_base": srv.URL,
		"qobuz_keys_url": claves.URL,
	})

	diag := c.DiagnosticoQobuz()
	if diag.Estado != EstadoFlac {
		t.Fatalf("estado = %q, se esperaba %q (detalle: %s)", diag.Estado, EstadoFlac, diag.Detalle)
	}
	if diag.Fuente != "origen" {
		t.Errorf("fuente = %q, se esperaba origen", diag.Fuente)
	}
}
