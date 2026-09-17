package flacrescue

// sitios_flac_flujo_test.go — Fija el FLUJO completo del canal de sitios
// raspables (búsqueda → pedido de descarga → enlace firmado) contra un
// servidor de prueba, y el ajuste "sitios" que llega de la app.
//
// Por qué aparte de sitios_flac_test.go: ahí vive la lectura del HTML y la
// elección del match (decisiones puras); acá, el recorrido con red simulada.
//
// Nunca sale a Internet: el servidor de prueba imita las respuestas del sitio.

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// TestResolverSitioRecorreBusquedaJobYEnlace comprueba el flujo completo contra
// un servidor de prueba que imita al sitio: búsqueda con formulario, pedido de
// descarga y espera del enlace firmado.
func TestResolverSitioRecorreBusquedaJobYEnlace(t *testing.T) {
	formulario := map[string]string{}
	var pidioBusqueda, pidioJob bool
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.URL.Path == "/":
			http.SetCookie(w, &http.Cookie{Name: "sl-session", Value: "abc", Path: "/"})
			_, _ = w.Write([]byte("<html>inicio</html>"))
		case r.URL.Path == "/search":
			pidioBusqueda = true
			if r.URL.Query().Get("query") != "QMFMF2447055" {
				t.Errorf("la búsqueda debe ir por ISRC, fue %q", r.URL.Query().Get("query"))
			}
			_, _ = w.Write([]byte(htmlBusqueda))
		case r.URL.Path == "/downloads" && r.Method == http.MethodPost:
			if err := r.ParseForm(); err != nil {
				t.Errorf("formulario ilegible: %v", err)
			}
			for _, k := range []string{"_token", "music_url", "resource_kind", "quality"} {
				formulario[k] = r.Form.Get(k)
			}
			_, _ = w.Write([]byte(`<span class="dl-btn-wrap" hx-get="http://` + r.Host +
				`/downloads/ceca4b02?inline=1" hx-trigger="every 1s"></span>`))
		case strings.HasPrefix(r.URL.Path, "/downloads/ceca4b02"):
			pidioJob = true
			_, _ = w.Write([]byte(`<span class="dl-btn-wrap"><a href="http://` + r.Host +
				`/downloads/ceca4b02/file?expires=1&amp;token=zz">Descargar</a></span>`))
		default:
			t.Errorf("petición inesperada: %s", r.URL.Path)
		}
	}))
	defer srv.Close()

	cliente := NewClient()
	cliente.sitios = []sitioFLAC{sitioSuperflac{url: srv.URL}}

	enlace, sitio, err := cliente.ResolverSitioFLAC("QMFMF2447055", "NUEVAYoL", "Bad Bunny", 183000, "FLAC")
	if err != nil {
		t.Fatalf("debería haber resuelto el FLAC: %v", err)
	}
	if sitio != "superflac" {
		t.Fatalf("sitio inesperado: %q", sitio)
	}
	// El enlace viene escapado en el HTML (&amp;) y hay que devolverlo usable.
	if enlace != srv.URL+"/downloads/ceca4b02/file?expires=1&token=zz" {
		t.Fatalf("enlace mal devuelto: %q", enlace)
	}
	if !pidioBusqueda || !pidioJob {
		t.Fatalf("faltó un paso del flujo: busqueda=%v job=%v", pidioBusqueda, pidioJob)
	}
	// El formulario debe llevar el token del resultado elegido, su link y la
	// calidad sin pérdida: si faltara el token, el sitio rechaza la descarga.
	if formulario["_token"] != "tok-nuevayol" {
		t.Fatalf("token equivocado: %q", formulario["_token"])
	}
	if formulario["music_url"] != "https://open.qobuz.com/track/312055179" {
		t.Fatalf("link equivocado: %q", formulario["music_url"])
	}
	if formulario["resource_kind"] != "track" || formulario["quality"] != "FLAC" {
		t.Fatalf("pedido mal formado: %v", formulario)
	}
}

// TestResolverSitioExigeTituloYArtista fija que sin identidad NO se consulta el
// sitio: sin datos con los que verificar el match, bajaría otra canción.
func TestResolverSitioExigeTituloYArtista(t *testing.T) {
	cliente := NewClient()
	if _, _, err := cliente.ResolverSitioFLAC("QMFMF2447055", "", "Bad Bunny", 0, "FLAC"); err == nil {
		t.Fatal("sin título no debe consultar el sitio")
	}
	if _, _, err := cliente.ResolverSitioFLAC("", "NUEVAYoL", "Bad Bunny", 0, "FLAC"); err == nil {
		t.Fatal("sin ISRC no debe consultar el sitio")
	}
}

// TestAjusteSitiosApagaYLimita fija el ajuste "sitios" que llega de la app.
func TestAjusteSitiosApagaYLimita(t *testing.T) {
	cliente := NewClient()
	cliente.SetSettings(map[string]string{"sitios": "off"})
	if len(cliente.listaSitios()) != 0 {
		t.Fatal("con off no debe quedar ningún sitio habilitado")
	}
	cliente.SetSettings(map[string]string{"sitios": "https://superflac.com"})
	if len(cliente.listaSitios()) != 1 {
		t.Fatal("el sitio de la lista debería quedar habilitado")
	}
	cliente.SetSettings(map[string]string{"sitios": "https://otracosa.com"})
	if len(cliente.listaSitios()) != 0 {
		t.Fatal("una URL desconocida no debe encender nada")
	}
}
