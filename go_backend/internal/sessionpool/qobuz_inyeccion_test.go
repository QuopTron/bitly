// qobuz_inyeccion_test.go — Cómo llega el default del pool de Qobuz.
//
// Por qué existe: la URL del Worker NO se escribe en el fuente. Un repo abierto
// que la lleva publica también su secreto (va en la ruta) y cualquiera usa tu
// cuota. El valor viaja INYECTADO en el build:
//
//	-ldflags "-X github.com/zarz/bitly/go_backend/internal/sessionpool.QobuzPoolURLInyectada=..."
//
// Sin inyección el default queda VACÍO (pool de fábrica apagado). Esto lo fija.

package sessionpool

import "testing"

func TestPoolDeFabricaVieneDeLaInyeccion(t *testing.T) {
	if QobuzPoolURLInyectada != "" {
		t.Fatalf("QobuzPoolURLInyectada debería estar vacía en el repo: %q", QobuzPoolURLInyectada)
	}
	if got := poolDeFabrica(); len(got) != 0 {
		t.Fatalf("sin inyección el default debería estar vacío: %v", got)
	}

	previo := QobuzPoolURLInyectada
	QobuzPoolURLInyectada = " https://mi-worker.example/pool/s3cr3to "
	t.Cleanup(func() { QobuzPoolURLInyectada = previo })

	got := poolDeFabrica()
	if len(got) != 1 || got[0] != "https://mi-worker.example/pool/s3cr3to" {
		t.Fatalf("con inyección el default debería ser esa URL (recortada): %v", got)
	}
}
