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
	arcodPorDefecto = false
	os.Exit(m.Run())
}
