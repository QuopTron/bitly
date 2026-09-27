// ─────────────────────────────────────────────────────────────
// testmain_test.go — Arranque de los tests del paquete flacrescue.
//
// Por qué existe: el canal Qobuz trae orígenes de claves de fábrica
// (defaultKeysURLs) para que el usuario no tenga que pegar credenciales, y el
// canal arcod viene encendido apuntando a su sitio real. En tests eso
// significaría salir a Internet: cualquier test que corra con la configuración
// vacía consultaría esos servicios, con resultados distintos según cómo estén
// ese día (y el canal arcod ganaría la resolución antes que los espejos que los
// tests quieren ejercitar).
//
// Acá se apagan para TODO el paquete (los tests son offline por contrato); los
// tests que verifican esos caminos los encienden ellos mismos apuntando a un
// servidor local (ver clienteArcod en arcod_flujo_test.go) o a los servicios
// reales con su variable de entorno (ver canales_red_test.go).
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"os"
	"testing"
	"time"
)

// clavesDeFabrica son los orígenes de claves de antes de apagarlos: la medición
// de red (TestRedQobuzFirmado) los necesita para probar el canal tal como lo ve
// el usuario recién instalado.
var clavesDeFabrica []string

// origenDeClavesDeFabrica devuelve una copia de esos orígenes.
func origenDeClavesDeFabrica() []string {
	return append([]string(nil), clavesDeFabrica...)
}

func TestMain(m *testing.M) {
	clavesDeFabrica = append([]string(nil), defaultKeysURLs...)
	defaultKeysURLs = nil
	// El respaldo a la API "oficial" de Qobuz se apunta a un destino inerte: si
	// no, cualquier test cuyo proxy devuelva 429/5xx (ver pedirQobuz) terminaría
	// consultando www.qobuz.com DE VERDAD, y los tests son offline por contrato.
	// Los tests del respaldo lo repuntan a su propio servidor local.
	qobuzAPIBaseOficial = "http://127.0.0.1:1/api.json/0.2"
	arcodPorDefecto = false
	// El canal stash-relay también sale a Internet por defecto (config del
	// relay + mint): se apaga para TODO el paquete y los tests que lo ejercitan
	// lo encienden apuntando a un servidor local (ver stash_relay_test.go).
	stashRelayPorDefecto = false
	// La comprobación del enlace del canal arcod es un GET real al CDN del
	// sitio (ver enlaceArcodSirveAudio): en tests se sustituye por un "sí"
	// para que ningún test dependa de terceros. La función REAL tiene su
	// propio test contra un servidor local (arcod_stream_test.go) y los tests
	// que quieren un enlace roto la sustituyen ellos mismos.
	comprobarEnlaceArcod = func(string, time.Time) error { return nil }
	os.Exit(m.Run())
}
