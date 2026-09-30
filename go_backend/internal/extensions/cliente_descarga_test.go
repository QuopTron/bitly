package extensions

import (
	"testing"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

// TestClienteDescargaExtPara_EsUnico fija el arreglo del reuso de conexiones:
// antes CADA llamada a file.download / file.downloadSegments creaba su propio
// cliente con su propio transporte, así que cada segmento de un DASH pagaba
// TCP + TLS desde cero. El cliente tiene que ser el mismo para todo el proceso.
func TestClienteDescargaExtPara_EsUnico(t *testing.T) {
	primero := clienteDescargaExtPara()
	segundo := clienteDescargaExtPara()
	if primero != segundo {
		t.Fatal("el cliente de descargas debe ser compartido, no uno por llamada")
	}
	// Y no debe identificarse con el cliente de fetches: ese tiene timeout
	// global de 30 s y mataría una descarga larga.
	if primero == clienteHTTPExtPara() {
		t.Fatal("las descargas necesitan su propio cliente (sin timeout global)")
	}
}

// TestClienteDescargaExtPara_ConfiguracionDeDescarga revisa los cuatro ajustes
// que hacen a una descarga fiable y rápida.
func TestClienteDescargaExtPara_ConfiguracionDeDescarga(t *testing.T) {
	cliente := clienteDescargaExtPara()

	if cliente.Timeout != 0 {
		t.Errorf("sin timeout global (un FLAC de 100 MB tarda lo que tarde), tiene %v", cliente.Timeout)
	}

	tr := httpclient.BaseDeConteo(cliente.Transport)
	if tr == nil {
		t.Fatal("el transporte debe ser *http.Transport")
	}

	// Fidelidad: los bytes escritos a disco deben ser los del archivo y
	// Content-Length tiene que seguir siendo confiable (guard de truncado).
	if !tr.DisableCompression {
		t.Error("la compresión transparente debe estar apagada en descargas")
	}

	// Robustez: sin esto, un servidor que acepta el TCP y se calla en el saludo
	// TLS colgaba la descarga para siempre (ResponseHeaderTimeout no lo cubre).
	if tr.TLSHandshakeTimeout <= 0 {
		t.Error("falta TLSHandshakeTimeout: un handshake colgado cuelga la descarga")
	}
	if tr.ResponseHeaderTimeout <= 0 {
		t.Error("falta ResponseHeaderTimeout")
	}

	// Velocidad: reuso de conexiones hacia el mismo CDN.
	if tr.MaxIdleConnsPerHost < 8 {
		t.Errorf("MaxIdleConnsPerHost = %d; con descargas por segmentos hace falta reusar más",
			tr.MaxIdleConnsPerHost)
	}
}

// TestClienteHTTPExtPara_ComprimeYReusa: el cliente de los fetch() de las
// extensiones sí comprime (HTML/JSON de los catálogos) y reusa conexiones.
func TestClienteHTTPExtPara_ComprimeYReusa(t *testing.T) {
	cliente := clienteHTTPExtPara()
	tr := httpclient.BaseDeConteo(cliente.Transport)
	if tr == nil {
		t.Fatal("el transporte debe ser *http.Transport")
	}
	if tr.DisableCompression {
		t.Error("los fetch() de extensiones deben comprimir: el grueso es HTML/JSON")
	}
	if tr.MaxIdleConnsPerHost < 8 {
		t.Errorf("MaxIdleConnsPerHost = %d, se esperaba reuso amplio", tr.MaxIdleConnsPerHost)
	}
	if tr.TLSHandshakeTimeout <= 0 || tr.ResponseHeaderTimeout <= 0 {
		t.Error("faltan los techos de handshake/cabeceras")
	}
}
