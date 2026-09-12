// ─────────────────────────────────────────────────────────────
// orchestrator_parciales.go — Identidad de los archivos parciales.
//
// Por qué existe: reanudar una descarga con `Range: bytes=N-` exige que el
// archivo parcial sea EXACTAMENTE el prefijo del mismo contenido que se va a
// pedir. Si no lo es, el resultado es un archivo cosido con dos audios
// distintos: el síntoma que se ve es una canción que "arranca desde la
// mitad" (arranca con el final de otra pista, o con un fragmento a mitad de
// camino).
//
// Cómo: el nombre del parcial lleva la identidad del destino
//   dl-<pista>-<huella>-<aleatorio><ext>
// y la búsqueda exige ese prefijo completo. Así un parcial de otra canción
// nunca se adopta.
//
// La huella ignora el query string a propósito: las URLs firmadas de los CDN
// (Deezer/Tidal/Qobuz) cambian la firma en cada petición, pero el mismo
// proveedor + la misma pista siguen siendo el mismo audio. Hashear la URL
// entera haría que la reanudación no matcheara nunca y dejaría basura
// acumulándose en Descargas.
//
// Se conecta con: orchestrator_downloadfile.go, orchestrator_append.go.
// Parte del flujo: descarga de audio a disco (reanudación por rangos).
// ─────────────────────────────────────────────────────────────

package download

import (
	"hash/fnv"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

const (
	// prefijoParcial es el inicio común de todo archivo parcial reanudable.
	prefijoParcial = "dl-"
	// prefijoParalelo marca los temporales de la descarga por tramos. Nunca
	// se reanudan (descargarEnParalelo los escribe con offsets absolutos) y
	// por eso la búsqueda de parciales los ignora explícitamente.
	prefijoParalelo = "dl-par-"
)

// huellaFuente identifica la fuente de audio de forma estable: esquema, host
// y ruta, descartando el query string (firmas que expiran).
func huellaFuente(urlFuente string) string {
	estable := urlFuente
	if u, err := url.Parse(urlFuente); err == nil && u.Host != "" {
		estable = u.Scheme + "://" + u.Host + u.Path
	}
	h := fnv.New64a()
	_, _ = h.Write([]byte(estable))
	return strconv.FormatUint(h.Sum64(), 16)
}

// nombreParcial arma el patrón (con el '*' que reemplaza os.CreateTemp) del
// archivo parcial de una pista: dl-<pista>-<huella>-*<ext>.
func nombreParcial(pistaLimpia, huella, ext string, paralelo bool) string {
	prefijo := prefijoParcial
	if paralelo {
		prefijo = prefijoParalelo
	}
	return prefijo + pistaLimpia + "-" + huella + "-*" + ext
}

// buscarParcial devuelve la ruta y el tamaño del parcial reanudable de
// [pistaLimpia]+[huella] en [dir], o ("", 0) si no hay ninguno.
//
// Exige el prefijo completo: un parcial de OTRA pista no se adopta, y como
// usar su tamaño como offset corrompería el audio, es la diferencia entre
// reanudar bien y servir una canción cosida.
func buscarParcial(dir, pistaLimpia, huella, ext string) (string, int64) {
	esperado := prefijoParcial + pistaLimpia + "-" + huella + "-"
	entradas, err := os.ReadDir(dir)
	if err != nil {
		return "", 0
	}
	for _, e := range entradas {
		if e.IsDir() {
			continue
		}
		nombre := e.Name()
		// Los temporales de la descarga paralela nunca se reanudan.
		if strings.HasPrefix(nombre, prefijoParalelo) {
			continue
		}
		if !strings.HasPrefix(nombre, esperado) || !strings.HasSuffix(nombre, ext) {
			continue
		}
		if info, ierr := e.Info(); ierr == nil && info.Size() > 0 {
			return filepath.Join(dir, nombre), info.Size()
		}
	}
	return "", 0
}
