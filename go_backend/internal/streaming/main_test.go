package streaming

import (
	"os"
	"testing"
)

// TestMain apaga la caché de URLs de stream para TODA la suite del paquete.
//
// Por qué: la caché vive 30 segundos entre llamadas (vidaMemoStreamURL) y los
// tests comparten proceso y a veces la misma pareja proveedor+identidad: una
// entrada guardada por el test anterior le robaba las llamadas al siguiente y
// sus afirmaciones de conteo dejaban de ser ciertas. Que cada prueba mida sus
// propias llamadas vale más que el hecho de que la caché esté siempre activa.
//
// Las pruebas de la PROPIA caché la vuelven a encender (ver
// stream_url_memo_test.go), y las que miden la reproducción contra la red real
// también, para que el número que reporten sea el del usuario.
func TestMain(m *testing.M) {
	MemoStreamURL(false)
	os.Exit(m.Run())
}
