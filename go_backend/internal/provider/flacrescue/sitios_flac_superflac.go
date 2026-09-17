// ─────────────────────────────────────────────────────────────
// sitios_flac_superflac.go — Protocolo raspable de superflac.com, un
// sitio que entrega el FLAC REAL sin cuenta y sin captcha (probado:
// 21,6 MB de un álbum de 3:03 con etiquetas e ISRC dentro, en ~3 s).
//
// El flujo del sitio, replicado acá:
//  1. GET  /                      → cookie de sesión
//  2. GET  /search?source=all&type=track&query=<ISRC>
//                                 → formularios con _token + music_url
//  3. POST /downloads?inline=1    → devuelve la URL de un TRABAJO
//  4. GET  /downloads/<uuid>      → se consulta cada 1 s hasta que
//                                   aparece el enlace firmado
//  5. GET  /downloads/<uuid>/file?expires=…&token=…  ← el FLAC
//
// El enlace del paso 5 es el archivo COMPLETO y no soporta Range (probado:
// ignora la cabecera y devuelve los 21,6 MB), por eso NUNCA se usa como
// stream: solo como origen de una DESCARGA.
//
// Se conecta con: sitios_flac.go (registro) y sitios_flac_lectura.go.
// Parte del flujo: rescate de FLAC por descarga (no streaming).
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"fmt"
	"net/url"
	"regexp"
	"time"
)

const (
	baseSuperflac = "https://superflac.com"
	// esperaEnlaceSitio es lo máximo que se espera el trabajo de descarga del
	// sitio. Mide 2-4 s en la práctica; el resto es holgura por si encola.
	esperaEnlaceSitio = 25 * time.Second
	// pasoConsultaSitio es cada cuánto se pregunta si el trabajo terminó.
	pasoConsultaSitio = 900 * time.Millisecond
	// timeoutSitio es el techo de UNA petición al sitio (búsqueda incluida).
	timeoutSitio = 20 * time.Second
)

var (
	reTrabajoSitio = regexp.MustCompile(`hx-get="(https?://[^"]*/downloads/[^"]+)"`)
	reArchivoSitio = regexp.MustCompile(`href="([^"]*/file\?[^"]*)"`)
)

// sitioSuperflac implementa sitioFLAC contra superflac.com. La base es un
// campo (y no la constante) para poder apuntar el protocolo a un servidor de
// prueba en los tests.
type sitioSuperflac struct{ url string }

// nuevoSitioSuperflac arma el sitio con su dirección real.
func nuevoSitioSuperflac() sitioSuperflac { return sitioSuperflac{url: baseSuperflac} }

func (sitioSuperflac) nombre() string { return "superflac" }
func (s sitioSuperflac) base() string { return s.url }

// resolver recorre el flujo del sitio y devuelve el enlace firmado del FLAC.
// La verificación del match la hace elegirCandidato: el sitio busca por texto
// y devuelve resultados aproximados cuando el ISRC no existe.
func (s sitioSuperflac) resolver(isrc, titulo, artista string, durMS int, formato string) (string, error) {
	sesion, err := nuevaSesionSitio()
	if err != nil {
		return "", err
	}
	if _, err := pedirSitio(sesion, s.url+"/"); err != nil {
		return "", fmt.Errorf("no se pudo abrir el sitio: %w", err)
	}
	consulta := s.url + "/search?" + url.Values{
		"source": {"all"}, "type": {"track"}, "query": {isrc},
	}.Encode()
	pagina, err := pedirSitio(sesion, consulta)
	if err != nil {
		return "", fmt.Errorf("la búsqueda falló: %w", err)
	}
	sinPerdida := normalizarFormato(formato) == "FLAC"
	elegido, err := elegirCandidato(leerCandidatos(pagina), titulo, artista, durMS, sinPerdida)
	if err != nil {
		return "", err
	}
	calidad := calidadPedida(elegido.calidades, formato)
	if calidad == "" {
		return "", fmt.Errorf("el sitio no ofrece una calidad pedible")
	}
	trabajo, err := pedirDescargaSitio(sesion, s.url, elegido, calidad)
	if err != nil {
		return "", err
	}
	return esperarEnlaceSitio(sesion, trabajo)
}
