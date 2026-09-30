package download

import (
	"os"
	"testing"
)

// TestMain apaga la caché de detalle (GetTrack) para TODA la suite del paquete.
//
// Por qué: la caché vive 60 segundos entre llamadas (vidaMemoDetalle) y los
// tests comparten proceso y a veces el MISMO nombre de proveedor con datos
// distintos (orchestrator_verify_isrc_test.go crea un stub por test con id "1"):
// una entrada guardada por la prueba anterior le robaba la llamada a la
// siguiente y sus afirmaciones dejaban de ser ciertas. Que cada prueba mida sus
// propias llamadas vale más que el hecho de que la caché esté siempre activa.
//
// Las pruebas de la propia caché la vuelven a encender (ver memo_detalle_test.go).
func TestMain(m *testing.M) {
	MemoDetalle(false)
	os.Exit(m.Run())
}
