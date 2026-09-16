// ─────────────────────────────────────────────────────────────
// testmain_test.go — Arranque de los tests del paquete flacrescue.
//
// Por qué existe: el canal Qobuz trae orígenes de claves de fábrica
// (defaultKeysURLs) para que el usuario no tenga que pegar credenciales.
// En tests eso significaría salir a Internet: cualquier test que corra
// con la configuración vacía consultaría el origen real, con resultados
// distintos según cómo esté ese sitio ese día.
//
// Acá se apagan para TODO el paquete (los tests son offline por
// contrato); el test que verifica el camino de fábrica los pone él
// mismo apuntando a un servidor local.
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"os"
	"testing"
)

func TestMain(m *testing.M) {
	defaultKeysURLs = nil
	os.Exit(m.Run())
}
