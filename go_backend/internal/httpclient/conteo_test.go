package httpclient

import (
	"errors"
	"net/http"
	"testing"
)

// transportePrueba es un RoundTripper que no toca la red: registra lo que le
// llega y devuelve una respuesta fija (o un error fijo). Sobre él se prueba el
// envoltorio de conteo, que no debe alterar ni la respuesta ni el error.
type transportePrueba struct {
	llegadas      int
	ultima        *http.Request
	cerradas      bool
	errDevolucion error
}

func (t *transportePrueba) RoundTrip(req *http.Request) (*http.Response, error) {
	t.llegadas++
	t.ultima = req
	if t.errDevolucion != nil {
		return nil, t.errDevolucion
	}
	return &http.Response{
		StatusCode: 200,
		Header:     make(http.Header),
		Body:       http.NoBody,
		Request:    req,
	}, nil
}

func (t *transportePrueba) CloseIdleConnections() { t.cerradas = true }

func peticiónDePrueba(t *testing.T, metodo, destino string) *http.Request {
	t.Helper()
	req, err := http.NewRequest(metodo, destino, nil)
	if err != nil {
		t.Fatalf("NewRequest: %v", err)
	}
	return req
}

// TestConteoCuentaPeticionesYSeReinicia fija lo que el diagnóstico promete:
// cada RoundTrip suma UNA petición, agrupada por host y método, y reiniciar
// deja todo en cero (el patrón reiniciar → un tap → leer).
func TestConteoCuentaPeticionesYSeReinicia(t *testing.T) {
	ReiniciarConteo()
	t.Cleanup(ReiniciarConteo)

	base := &transportePrueba{}
	envuelto := ContarTransporte(base)

	for i := 0; i < 3; i++ {
		if _, err := envuelto.RoundTrip(peticiónDePrueba(t, "GET", "https://cdn.ejemplo/a.flac")); err != nil {
			t.Fatalf("RoundTrip: %v", err)
		}
	}
	if _, err := envuelto.RoundTrip(peticiónDePrueba(t, "POST", "https://api.otro.test/buscar")); err != nil {
		t.Fatalf("RoundTrip: %v", err)
	}

	estado := EstadoConteo()
	if estado.Total != 4 {
		t.Fatalf("total = %d; se esperaba 4 peticiones", estado.Total)
	}
	if estado.PorHost["cdn.ejemplo"] != 3 {
		t.Errorf("cdn.ejemplo = %d, se esperaba 3", estado.PorHost["cdn.ejemplo"])
	}
	if estado.PorHost["api.otro.test"] != 1 {
		t.Errorf("api.otro.test = %d, se esperaba 1", estado.PorHost["api.otro.test"])
	}
	if estado.PorMetodo["GET"] != 3 || estado.PorMetodo["POST"] != 1 {
		t.Errorf("métodos = %v, se esperaba GET=3 POST=1", estado.PorMetodo)
	}

	// La copia es una copia: tocarla no puede alterar el acumulado.
	estado.PorHost["cdn.ejemplo"] = 999
	if EstadoConteo().PorHost["cdn.ejemplo"] != 3 {
		t.Error("EstadoConteo devolvió el mapa interno, no una copia")
	}

	ReiniciarConteo()
	if tras := EstadoConteo(); tras.Total != 0 || len(tras.PorHost) != 0 {
		t.Fatalf("tras reiniciar: total=%d hostes=%d; se esperaba todo en cero", tras.Total, len(tras.PorHost))
	}
}

// TestConteoNoTocaLaRespuestaNiElError: el envoltorio es solo observación. Si
// devolviera otra respuesta o enmascarara el error, estaría corrompiendo el
// stream y las descargas — que es exactamente lo contrario de lo buscado.
func TestConteoNoTocaLaRespuestaNiElError(t *testing.T) {
	ReiniciarConteo()
	t.Cleanup(ReiniciarConteo)

	// Respuesta: pasa la misma y el mismo número de RoundTrip.
	base := &transportePrueba{}
	envuelto := ContarTransporte(base)
	respuesta, err := envuelto.RoundTrip(peticiónDePrueba(t, "GET", "https://cdn.ejemplo/x"))
	if err != nil {
		t.Fatalf("RoundTrip: %v", err)
	}
	if base.llegadas != 1 {
		t.Errorf("el RoundTrip interno se llamó %d veces, se esperaba 1", base.llegadas)
	}
	if respuesta == nil || respuesta.StatusCode != 200 {
		t.Error("el envoltorio alteró la respuesta")
	}

	// Error: se propaga tal cual.
	fallo := errors.New("timeout simulado")
	base.errDevolucion = fallo
	if _, err := envuelto.RoundTrip(peticiónDePrueba(t, "GET", "https://cdn.ejemplo/y")); !errors.Is(err, fallo) {
		t.Errorf("error = %v, se esperaba que se propagara %v", err, fallo)
	}
	// Y la petición rechazada también cuenta: costó una ida a la red.
	if EstadoConteo().Total != 2 {
		t.Errorf("total = %d; la petición fallida también debe contar", EstadoConteo().Total)
	}
}

// TestConteoPropagaCloseIdleConnections: envolver no puede costarle al proceso
// la capacidad de tirar conexiones ociosas (la usan los tests del ajuste
// global y el cierre del canal de rescate al cambiar de proxy).
func TestConteoPropagaCloseIdleConnections(t *testing.T) {
	base := &transportePrueba{}
	envuelto := ContarTransporte(base).(interface{ CloseIdleConnections() })
	envuelto.CloseIdleConnections()
	if !base.cerradas {
		t.Error("CloseIdleConnections no se propagó al transporte de adentro")
	}
}

// TestContarTransporteEsIdempotente: si cada punto de instalación volviera a
// envolver, una petición pasaría por N wrappers (y un mismo wrapper anidado
// contaría dos veces). Idempotente = instalar desde varios sitios es seguro.
func TestContarTransporteEsIdempotente(t *testing.T) {
	base := &transportePrueba{}
	una := ContarTransporte(base)
	dos := ContarTransporte(una)
	if una != dos {
		t.Error("envolver dos veces creó un segundo envoltorio; debe devolver el mismo")
	}
	// Un nil se resuelve al transporte por defecto, sin apuntarse a sí mismo.
	nulo := ContarTransporte(nil)
	if nulo == nil {
		t.Fatal("ContarTransporte(nil) devolvió nil")
	}
	if _, ok := nulo.(*transporteConteo); !ok {
		t.Error("ContarTransporte(nil) no devolvió el envoltorio de conteo")
	}
}

// TestBaseDeConteoDesenvuelve comprueba el acceso al transporte real de
// adentro: es lo que usan los tests del ajuste global y los de las
// extensiones para leer MaxIdleConnsPerHost sin que el envoltorio se
// interponga en la aserción de tipos.
func TestBaseDeConteoDesenvuelve(t *testing.T) {
	real := &http.Transport{}
	if got := BaseDeConteo(ContarTransporte(real)); got != real {
		t.Error("BaseDeConteo no desenvolvió el envoltorio de conteo")
	}
	if got := BaseDeConteo(real); got != real {
		t.Error("BaseDeConteo devolvió nil para un transporte que no estaba envuelto")
	}
	if got := BaseDeConteo(&transportePrueba{}); got != nil {
		t.Error("BaseDeConteo debía devolver nil para algo que no es *http.Transport")
	}
}
