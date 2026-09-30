// ─────────────────────────────────────────────────────────────
// proxy_test.go — El ajuste de proxy tiene que cubrir TODO el egreso
// del rescate: los espejos, las sesiones de los sitios raspables, el
// canal arcod y el origen de claves de Qobuz (ver proxy.go).
//
// Se prueba con un servidor de prueba que hace de PROXY HTTP: la
// petición llega con la URL absoluta del espejo en la línea de
// petición, que es exactamente lo que distingue "salió por el proxy"
// de "salió directo".
//
// Sin red real: el espejo y el CDN son hosts .invalid, que nunca se
// resuelven (y con proxy ni se intenta).
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

// proxyDePrueba arma un servidor que acepta peticiones en forma de proxy y
// devuelve el JSON del contrato de los espejos. Devuelve también un puntero a
// los hosts que recibió, para poder afirmar por dónde salió la petición.
func proxyDePrueba(t *testing.T) (*httptest.Server, *[]string) {
	t.Helper()
	recibidos := &[]string{}
	servidor := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		*recibidos = append(*recibidos, r.URL.Host)
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{
			"url": "http://cdn-falso.invalid/audio.flac",
		})
	}))
	t.Cleanup(servidor.Close)
	t.Cleanup(func() { SetProxy("") })
	return servidor, recibidos
}

// TestProxyCubreLosEspejos fija lo que pidió el usuario: TODOS los sitios (acá
// los espejos del contrato monochrome) salen por el proxy configurado.
func TestProxyCubreLosEspejos(t *testing.T) {
	proxy, recibidos := proxyDePrueba(t)

	c := NewClient()
	// arcod apagado para que la resolución caiga sí o sí en los espejos
	// (testmain_test.go ya lo apaga, esto lo hace explícito).
	c.SetSettings(map[string]string{
		"arcod":   "off",
		"mirrors": "http://espejo-falso.invalid",
		"proxy":   proxy.URL,
	})

	if Proxy() != proxy.URL {
		t.Fatalf("Proxy()=%q, se esperaba %q", Proxy(), proxy.URL)
	}

	url, err := c.GetStreamURL("USUG12607940", "FLAC")
	if err != nil {
		t.Fatalf("GetStreamURL falló con proxy configurado: %v", err)
	}
	if url == "" {
		t.Fatal("GetStreamURL devolvió URL vacía")
	}
	if len(*recibidos) == 0 {
		t.Fatal("el proxy no recibió ninguna petición: los espejos salieron directo")
	}
	for _, host := range *recibidos {
		if host != "espejo-falso.invalid" {
			t.Fatalf("el proxy recibió el host %q, se esperaba espejo-falso.invalid", host)
		}
	}
}

// TestProxyCubreSitiosRaspables comprueba que las sesiones de los sitios
// raspables comparten el MISMO transporte, que es lo que hace que el ajuste
// cubra también a superflac y sus instancias (las que más bloquean por
// región).
func TestProxyCubreSitiosRaspables(t *testing.T) {
	sesion, err := nuevaSesionSitio()
	if err != nil {
		t.Fatalf("nuevaSesionSitio: %v", err)
	}
	if sesion.Transport != transporteRescateContado {
		t.Fatal("la sesión del sitio no usa el transporte compartido: el proxy no la cubriría")
	}
	if NewClient().http.Transport != transporteRescateContado {
		t.Fatal("el cliente de espejos/arcod/Qobuz no usa el transporte compartido")
	}
}

// TestProxyCubreLaComprobacionDelEnlaceArcod: la comprobación que se le hace al
// enlace firmado de arcod NO puede salir directa. Va a OTRO host
// (api.arcod.xyz) que el catálogo, y si la región del usuario está bloqueada esa
// comprobación fallaba por su cuenta: el canal creía que el enlace no servía y
// el rescate seguía de largo sin motivo.
func TestProxyCubreLaComprobacionDelEnlaceArcod(t *testing.T) {
	proxy, recibidos := proxyDePrueba(t)
	SetProxy(proxy.URL)

	const enlace = "http://cdn-arcod.invalid/v2/stream/play?t=v1.abc"
	if err := enlaceArcodSirveAudio(enlace, time.Now().Add(2*time.Second)); err != nil {
		t.Fatalf("el enlace (200 del proxy) debería servir: %v", err)
	}
	if len(*recibidos) == 0 {
		t.Fatal("la comprobación salió directo: el proxy no la vio")
	}
	for _, host := range *recibidos {
		if host != "cdn-arcod.invalid" {
			t.Fatalf("el proxy recibió el host %q, se esperaba cdn-arcod.invalid", host)
		}
	}
}

// TestProxyBestEffort fija el contrato de seguridad del ajuste: un valor mal
// pegado NO puede dejar el rescate sin salida.
func TestProxyBestEffort(t *testing.T) {
	t.Cleanup(func() { SetProxy("") })
	const bueno = "http://proxy-bueno.invalid:8080"
	SetProxy(bueno)

	// Sin esquema reconocido, sin host, o directamente basura: se conserva el
	// proxy anterior en vez de borrarlo.
	for _, malo := range []string{"no-es-una-url", "ftp://proxy.invalid:21", "http://"} {
		SetProxy(malo)
		if Proxy() != bueno {
			t.Fatalf("Proxy()=%q tras pegar %q, se esperaba conservar %q", Proxy(), malo, bueno)
		}
	}

	// Vacío (o solo espacios) es el usuario borrando el campo: modo directo.
	SetProxy("   ")
	if Proxy() != "" {
		t.Fatalf("Proxy()=%q tras borrar el campo, se esperaba vacío", Proxy())
	}

	SetProxy("socks5h://usuario:clave@proxy.invalid:1080")
	if got := Proxy(); got != "socks5h://usuario:clave@proxy.invalid:1080" {
		t.Fatalf("Proxy()=%q, se esperaba el SOCKS5 con credenciales", got)
	}

	// Borrar el campo vuelve al modo directo.
	SetProxy("")
	if Proxy() != "" {
		t.Fatalf("Proxy()=%q tras borrar el ajuste, se esperaba vacío", Proxy())
	}
}
