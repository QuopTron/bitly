// qobuz_inyeccion_test.go — Los defaults del canal Qobuz que viajan INYECTADOS.
//
// Por qué existe: ni la ruta /keys ni la base de la API del Worker personal se
// escriben en el fuente (un repo abierto publicaría su URL y su secreto). Sin
// inyección, el canal va DIRECTO a Qobuz y usa el origen público de claves: el
// Worker es opt-in, no un default que arrastre a todos los que compilen.

package flacrescue

import (
	"strings"
	"testing"
)

func TestKeysURLsYBaseDeFabricaVienenDeLaInyeccion(t *testing.T) {
	if QobuzKeysURLInyectada != "" || QobuzAPIBaseInyectada != "" {
		t.Fatal("las var inyectadas deberían estar vacías en el repo")
	}

	// Sin inyección: queda el origen público de siempre, y la base va a Qobuz.
	urls := keysURLsDeFabrica()
	if len(urls) != 1 || !strings.Contains(urls[0], "flacdownloader.com") {
		t.Fatalf("sin inyección debería quedar sólo el origen público: %v", urls)
	}
	if got := baseDeFabrica(); got != qobuzAPIBaseOficial {
		t.Fatalf("sin inyección la base debería ser la de Qobuz: %q", got)
	}

	previoKeys, previaBase := QobuzKeysURLInyectada, QobuzAPIBaseInyectada
	QobuzKeysURLInyectada = " https://mi-worker.example/s3cr3to/keys "
	QobuzAPIBaseInyectada = "https://mi-worker.example/s3cr3to/api.json/0.2"
	t.Cleanup(func() { QobuzKeysURLInyectada, QobuzAPIBaseInyectada = previoKeys, previaBase })

	urls = keysURLsDeFabrica()
	if len(urls) != 2 || urls[0] != "https://mi-worker.example/s3cr3to/keys" {
		t.Fatalf("con inyección el Worker propio va primero: %v", urls)
	}
	if got := baseDeFabrica(); got != QobuzAPIBaseInyectada {
		t.Fatalf("con inyección la base es la del Worker: %q", got)
	}
}
