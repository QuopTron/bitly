package httpclient

import (
	"net/http"
	"testing"
	"time"
)

// TestTransporteGlobalSeAjustaUnaSolaVez fija que el ajuste del transporte
// global se aplique en el arranque del paquete y que una llamada POSTERIOR no
// vuelva a escribir esos campos.
//
// Por qué importa: mutar los campos de un transporte que ya tiene peticiones en
// vuelo es un data race —net/http lee MaxIdleConns, TLSHandshakeTimeout, etc. al
// mismo tiempo— y el race detector lo cazó en CI: el backend se inicializa más
// de una vez (los tests lo hacen) mientras la descarga del manager de binarios
// sigue corriendo en segundo plano. Este test lo caza sin el detector: si la
// función vuelve a escribir, pisa el valor que dejamos a mano.
func TestTransporteGlobalSeAjustaUnaSolaVez(t *testing.T) {
	tr, ok := http.DefaultTransport.(*http.Transport)
	if !ok || tr == nil {
		t.Skip("el transporte por defecto no es *http.Transport")
	}

	// 1) El arranque del paquete ya lo ajustó (si no, la optimización no sirve
	//    de nada: seguiría con 2 conexiones ociosas por host).
	if tr.MaxIdleConnsPerHost != 16 {
		t.Fatalf("el transporte no quedó ajustado en el arranque: MaxIdleConnsPerHost=%d", tr.MaxIdleConnsPerHost)
	}

	// 2) Una segunda "inicialización del backend" no puede tocar nada.
	previo := tr.MaxIdleConnsPerHost
	tr.MaxIdleConnsPerHost = 7
	t.Cleanup(func() { tr.MaxIdleConnsPerHost = previo })

	OptimizarTransportePorDefecto()
	if tr.MaxIdleConnsPerHost != 7 {
		t.Fatalf(
			"la función volvió a mutar el transporte (MaxIdleConnsPerHost=%d): esa escritura es la que corre en paralelo con las peticiones en vuelo",
			tr.MaxIdleConnsPerHost,
		)
	}
}

// TestTransporteGlobalAjustaIdleYTimeouts fija que el ajuste sigue subiendo los
// límites que hacían lento el reuso de conexiones: con 2 ociosas por host cada
// petición extra al mismo CDN reabría un handshake TLS.
func TestTransporteGlobalAjustaIdleYTimeouts(t *testing.T) {
	tr, ok := http.DefaultTransport.(*http.Transport)
	if !ok || tr == nil {
		t.Skip("el transporte por defecto no es *http.Transport")
	}
	if tr.MaxIdleConns != 128 || tr.MaxIdleConnsPerHost != 16 {
		t.Fatalf(
			"pool de conexiones sin ajustar: MaxIdleConns=%d MaxIdleConnsPerHost=%d",
			tr.MaxIdleConns, tr.MaxIdleConnsPerHost,
		)
	}
	if tr.TLSHandshakeTimeout != 10*time.Second || tr.ResponseHeaderTimeout != 25*time.Second {
		t.Fatalf(
			"esperas sin techo: handshake=%s cabeceras=%s",
			tr.TLSHandshakeTimeout, tr.ResponseHeaderTimeout,
		)
	}
	if !tr.ForceAttemptHTTP2 {
		t.Fatal("HTTP/2 debería estar habilitado para multiplexar los rangos del stream")
	}
}
